package io.nimzo.app;

import androidx.annotation.NonNull;
import io.flutter.embedding.android.FlutterActivity;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.plugin.common.MethodChannel;

/** Temporary SDK-deferred Android entrypoint. Full Vivox sources are preserved. */
public final class MainActivity extends FlutterActivity {
  private NimzoUpdate appUpdates;
  @Override
  public void configureFlutterEngine(@NonNull FlutterEngine flutterEngine) {
    super.configureFlutterEngine(flutterEngine);
    // Safely recover auth plugins when auto-registration skipped them.
    if (!flutterEngine.getPlugins().has(
        io.flutter.plugins.sharedpreferences.SharedPreferencesPlugin.class)) {
      flutterEngine.getPlugins().add(
          new io.flutter.plugins.sharedpreferences.SharedPreferencesPlugin());
    }
    if (!flutterEngine.getPlugins().has(
        com.llfbandit.app_links.AppLinksPlugin.class)) {
      flutterEngine.getPlugins().add(new com.llfbandit.app_links.AppLinksPlugin());
    }
    // Native Android preferences fallback for the legacy Flutter session store.
    // Access only project session/PKCE keys; never clear all preferences.
    new MethodChannel(flutterEngine.getDartExecutor().getBinaryMessenger(),
        "nimzo/auth_storage").setMethodCallHandler((call, result) -> {
      if ("probe".equals(call.method)) {
        result.success(true);
        return;
      }
      String key = call.argument("key");
      if (key == null || key.length() > 220 ||
          !key.matches("[a-zA-Z0-9_.:-]+") ||
          !(key.startsWith("sb-") || key.equals("SUPABASE_PERSIST_SESSION_KEY") ||
            key.equals("supabase.auth.token-code-verifier"))) {
        result.error("STORAGE_KEY_INVALID", "Invalid auth storage key", null);
        return;
      }
      try {
        android.content.SharedPreferences prefs =
            getSharedPreferences("FlutterSharedPreferences", MODE_PRIVATE);
        String nativeKey = "flutter." + key;
        switch (call.method) {
          case "read":
            result.success(prefs.getString(nativeKey, null));
            break;
          case "contains":
            result.success(prefs.contains(nativeKey));
            break;
          case "write":
            String value = call.argument("value");
            if (value == null || value.length() > 1048576) {
              result.error("STORAGE_VALUE_INVALID", "Invalid session value", null);
              return;
            }
            if (prefs.edit().putString(nativeKey, value).commit()) result.success(true);
            else result.error("STORAGE_WRITE_FAILED", "Session write failed", null);
            break;
          case "remove":
            if (prefs.edit().remove(nativeKey).commit()) result.success(true);
            else result.error("STORAGE_REMOVE_FAILED", "Session removal failed", null);
            break;
          default:
            result.notImplemented();
        }
      } catch (RuntimeException e) {
        // Do not log exception messages, stack traces or stored session values.
        result.error("NATIVE_STORAGE_FAILED", "Android auth storage unavailable", null);
      }
    });
    appUpdates = new NimzoUpdate(this);
    new MethodChannel(flutterEngine.getDartExecutor().getBinaryMessenger(), "nimzo/app_update")
      .setMethodCallHandler((call, result) -> {
        if (!"downloadAndInstall".equals(call.method)) {
          result.notImplemented(); return;
        }
        appUpdates.download(call.argument("url"), call.argument("sha256"),
            call.argument("signingCertificateSha256"), call.argument("packageName"),
            call.argument("buildNumber"), result);
      });
    // No JNI or native voice code is included in this test build.
    new MethodChannel(flutterEngine.getDartExecutor().getBinaryMessenger(), "nimzo/vivox")
      .setMethodCallHandler((call, result) -> {
        result.error("VOICE_SDK_PENDING",
            "Vivox SDK is disabled in this temporary test build.", null);
      });
  }
  @Override
  protected void onResume() {
    super.onResume();
    if (appUpdates != null) appUpdates.onResume();
  }
  @Override
  protected void onDestroy() {
    if (appUpdates != null) appUpdates.destroy();
    super.onDestroy();
  }
}
