package io.nimzo.app;

import android.app.Activity;
import android.content.ClipData;
import android.content.Intent;
import android.content.SharedPreferences;
import android.widget.Toast;
import android.content.pm.PackageInfo;
import android.content.pm.PackageManager;
import android.net.Uri;
import android.os.Build;
import android.provider.Settings;
import androidx.core.content.FileProvider;
import io.flutter.plugin.common.MethodChannel;
import java.io.File;
import java.io.FileOutputStream;
import java.io.FileInputStream;
import java.io.InputStream;
import java.net.HttpURLConnection;
import java.net.URL;
import java.security.MessageDigest;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

/** User-requested updates only; Android verifies and confirms installation. */
public final class NimzoUpdate {
  private final Activity activity;
  private final ExecutorService worker = Executors.newSingleThreadExecutor();
  private final SharedPreferences pending;
  private boolean busy;
  private boolean destroyed;

  public NimzoUpdate(Activity activity) {
    this.activity = activity;
    this.pending = activity.getSharedPreferences("nimzo_verified_update", Activity.MODE_PRIVATE);
  }

  public void download(String address, String digest, String certificate, String packageName,
                       Number buildNumber, MethodChannel.Result result) {
    if (busy) { result.error("UPDATE_BUSY", "An update is already downloading.", null); return; }
    if (address == null || digest == null || certificate == null || buildNumber == null
        || !digest.matches("[a-fA-F0-9]{64}") || !certificate.matches("[a-fA-F0-9]{64}")
        || !activity.getPackageName().equals(packageName)) {
      result.error("UPDATE_METADATA", "The update metadata is invalid.", null); return;
    }
    busy = true;
    worker.execute(() -> {
      File apk = null;
      try {
        URL url = new URL(address);
        if (!trustedEntry(url)) throw new UpdateFailure("UPDATE_URL");
        File folder = new File(activity.getCacheDir(), "nimzo_updates");
        if (!folder.isDirectory() && !folder.mkdirs()) throw new UpdateFailure("UPDATE_STORAGE");
        apk = new File(folder, "update.apk");
        fetch(url, apk, digest);
        validate(apk, packageName, certificate, buildNumber.longValue());
        final File verified = apk;
        activity.runOnUiThread(() -> {
          busy = false;
          if (destroyed) return;
          try {
            if (Build.VERSION.SDK_INT >= 26 && !activity.getPackageManager().canRequestPackageInstalls()) {
              pending.edit().putString("sha256", digest).putString("certificate", certificate)
                  .putString("package", packageName).putLong("build", buildNumber.longValue()).apply();
              activity.startActivity(new Intent(Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
                  Uri.parse("package:" + activity.getPackageName())));
              result.success("permissionRequired");
            } else {
              openInstaller(verified);
              pending.edit().clear().apply();
              result.success("installerOpened");
            }
          } catch (Exception ignored) {
            pending.edit().clear().apply();
            result.error("UPDATE_INSTALLER", "Android could not open the package installer.", null);
          }
        });
      } catch (Exception error) {
        if (apk != null) apk.delete();
        final String code = error instanceof UpdateFailure ? ((UpdateFailure) error).code : "UPDATE_DOWNLOAD";
        activity.runOnUiThread(() -> {
          busy = false;
          if (!destroyed) result.error(code, "The update could not be verified or opened. Try again.", null);
        });
      }
    });
  }

  public void onResume() {
    if (busy || destroyed || !pending.contains("build") || (Build.VERSION.SDK_INT >= 26
        && !activity.getPackageManager().canRequestPackageInstalls())) return;
    busy = true;
    worker.execute(() -> {
      File apk = new File(activity.getCacheDir(), "nimzo_updates/update.apk");
      boolean valid = false;
      try {
        verifyFile(apk, pending.getString("sha256", ""));
        validate(apk, pending.getString("package", ""), pending.getString("certificate", ""),
            pending.getLong("build", 0));
        valid = true;
      } catch (Exception ignored) { /* Safe retry feedback is shown below. */ }
      final boolean verified = valid;
      activity.runOnUiThread(() -> {
        busy = false;
        if (destroyed) return;
        pending.edit().clear().apply();
        try {
          if (!verified) throw new UpdateFailure("UPDATE_VERIFICATION");
          openInstaller(apk);
        } catch (Exception ignored) {
          Toast.makeText(activity, "The update could not be opened. Tap Check for updates to retry.",
              Toast.LENGTH_LONG).show();
        }
      });
    });
  }

  public void destroy() { destroyed = true; worker.shutdownNow(); }

  private void openInstaller(File apk) {
    Uri uri = FileProvider.getUriForFile(activity, activity.getPackageName() + ".apk_updates", apk);
    Intent intent = new Intent(Intent.ACTION_VIEW);
    intent.setDataAndType(uri, "application/vnd.android.package-archive");
    intent.setClipData(ClipData.newRawUri("NIMZO verified update", uri));
    intent.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION);
    activity.startActivity(intent);
  }

  private static boolean trustedEntry(URL url) {
    return url.getProtocol().equals("https") && url.getHost().equals("github.com")
        && url.getPort() == -1 && url.getUserInfo() == null && url.getQuery() == null
        && url.getRef() == null && url.getPath().matches("/adi4ch-cmd/Nimzo/releases/download/[^/]+/app-release\\.apk");
  }

  private static boolean trustedRedirect(URL url) {
    return url.getProtocol().equals("https") && url.getPort() == -1 && url.getUserInfo() == null
        && (url.getHost().equals("github.com") || url.getHost().equals("release-assets.githubusercontent.com")
            || url.getHost().equals("objects.githubusercontent.com"));
  }

  private static void fetch(URL url, File target, String expected) throws Exception {
    long deadline = android.os.SystemClock.elapsedRealtime() + 600000;
    for (int redirects = 0; redirects <= 5; redirects++) {
      HttpURLConnection connection = (HttpURLConnection) url.openConnection();
      connection.setInstanceFollowRedirects(false);
      connection.setConnectTimeout(15000);
      connection.setReadTimeout(15000);
      connection.setRequestProperty("User-Agent", "NIMZO-Android-Update");
      try {
        int status = connection.getResponseCode();
        if (status == 301 || status == 302 || status == 303 || status == 307 || status == 308) {
          String location = connection.getHeaderField("Location");
          if (location == null) throw new UpdateFailure("UPDATE_REDIRECT");
          URL next = new URL(url, location);
          if (!trustedRedirect(next)) throw new UpdateFailure("UPDATE_REDIRECT");
          url = next;
          continue;
        }
        if (status != 200) throw new UpdateFailure("UPDATE_DOWNLOAD");
        MessageDigest hash = MessageDigest.getInstance("SHA-256");
        long total = 0;
        try (InputStream stream = connection.getInputStream(); FileOutputStream output = new FileOutputStream(target)) {
          byte[] buffer = new byte[65536]; int count;
          while ((count = stream.read(buffer)) != -1) {
            if (Thread.currentThread().isInterrupted() || android.os.SystemClock.elapsedRealtime() > deadline)
              throw new UpdateFailure("UPDATE_TIMEOUT");
            total += count;
            if (total > 512L * 1024 * 1024) throw new UpdateFailure("UPDATE_SIZE");
            hash.update(buffer, 0, count); output.write(buffer, 0, count);
          }
        }
        if (total == 0 || !hex(hash.digest()).equalsIgnoreCase(expected)) throw new UpdateFailure("UPDATE_CHECKSUM");
        return;
      } finally { connection.disconnect(); }
    }
    throw new UpdateFailure("UPDATE_REDIRECT");
  }

  private static void verifyFile(File file, String expected) throws Exception {
    MessageDigest hash = MessageDigest.getInstance("SHA-256");
    long total = 0;
    try (InputStream stream = new FileInputStream(file)) {
      byte[] buffer = new byte[65536]; int count;
      while ((count = stream.read(buffer)) != -1) {
        if (Thread.currentThread().isInterrupted()) throw new UpdateFailure("UPDATE_TIMEOUT");
        total += count;
        if (total > 512L * 1024 * 1024) throw new UpdateFailure("UPDATE_SIZE");
        hash.update(buffer, 0, count);
      }
    }
    if (total == 0 || !hex(hash.digest()).equalsIgnoreCase(expected)) throw new UpdateFailure("UPDATE_CHECKSUM");
  }

  @SuppressWarnings("deprecation")
  private void validate(File apk, String name, String expectedCertificate, long build) throws Exception {
    PackageManager manager = activity.getPackageManager();
    int flags = Build.VERSION.SDK_INT >= 28 ? PackageManager.GET_SIGNING_CERTIFICATES : PackageManager.GET_SIGNATURES;
    PackageInfo installed = manager.getPackageInfo(activity.getPackageName(), flags);
    PackageInfo incoming = manager.getPackageArchiveInfo(apk.getPath(), flags);
    if (incoming == null || !name.equals(incoming.packageName) || version(incoming) != build
        || version(incoming) <= version(installed)) throw new UpdateFailure("UPDATE_VERSION");
    String current = certificate(installed);
    if (!current.equalsIgnoreCase(expectedCertificate) || !certificate(incoming).equals(current))
      throw new UpdateFailure("UPDATE_SIGNATURE");
  }

  @SuppressWarnings("deprecation")
  private static long version(PackageInfo info) { return Build.VERSION.SDK_INT >= 28 ? info.getLongVersionCode() : info.versionCode; }

  @SuppressWarnings("deprecation")
  private static String certificate(PackageInfo info) throws Exception {
    android.content.pm.Signature[] signatures = Build.VERSION.SDK_INT >= 28
        ? (info.signingInfo == null ? null : info.signingInfo.getApkContentsSigners()) : info.signatures;
    if (signatures == null || signatures.length != 1) throw new UpdateFailure("UPDATE_SIGNATURE");
    return hex(MessageDigest.getInstance("SHA-256").digest(signatures[0].toByteArray()));
  }

  private static String hex(byte[] bytes) {
    StringBuilder text = new StringBuilder();
    for (byte value : bytes) text.append(String.format(java.util.Locale.ROOT, "%02x", value & 255));
    return text.toString();
  }

  private static final class UpdateFailure extends Exception {
    final String code;
    UpdateFailure(String code) { super(code); this.code = code; }
  }
}
