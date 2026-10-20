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
        if ("requestMicPermission".equals(call.method)) {
          result.success(false);
        } else {
          result.error("VOICE_SDK_PENDING",
              "Vivox SDK is disabled in this temporary test build.", null);
        }
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
