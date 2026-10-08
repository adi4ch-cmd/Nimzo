package io.nimzo.app;

import android.Manifest;
import android.content.pm.PackageManager;
import android.os.Build;
import androidx.annotation.NonNull;
import io.flutter.embedding.android.FlutterActivity;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.plugin.common.MethodChannel;
import io.nimzo.vivox.NimzoVivox;
import java.util.HashMap;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

public class MainActivity extends FlutterActivity {
  private static final String CHANNEL = "nimzo/vivox";
  private static final int AUDIO_PERMISSION = 4107;
  private final ExecutorService voiceWorker = Executors.newSingleThreadExecutor();
  private MethodChannel.Result permissionResult;
  private NimzoUpdate appUpdates;

  @Override
  public void configureFlutterEngine(@NonNull FlutterEngine flutterEngine) {
    super.configureFlutterEngine(flutterEngine);
    appUpdates = new NimzoUpdate(this);
    new MethodChannel(flutterEngine.getDartExecutor().getBinaryMessenger(), "nimzo/app_update")
        .setMethodCallHandler((call, result) -> {
          if (!call.method.equals("downloadAndInstall")) { result.notImplemented(); return; }
          appUpdates.download(call.argument("url"), call.argument("sha256"),
              call.argument("signingCertificateSha256"), call.argument("packageName"),
              call.argument("buildNumber"), result);
        });
    MethodChannel channel = new MethodChannel(flutterEngine.getDartExecutor().getBinaryMessenger(), CHANNEL);
    channel.setMethodCallHandler((call, result) -> {
      if (call.method.equals("requestMicPermission")) {
        if (Build.VERSION.SDK_INT < 23 || checkSelfPermission(Manifest.permission.RECORD_AUDIO) == PackageManager.PERMISSION_GRANTED) {
          result.success(true);
        } else if (permissionResult != null) {
          result.error("PERMISSION_PENDING", "An audio permission request is already open", null);
        } else {
          permissionResult = result;
          // Bluetooth audio is optional; requesting CONNECT on Android 12+ permits headset routing.
          String[] permissions = Build.VERSION.SDK_INT >= 31
              ? new String[]{Manifest.permission.RECORD_AUDIO, Manifest.permission.BLUETOOTH_CONNECT}
              : new String[]{Manifest.permission.RECORD_AUDIO};
          requestPermissions(permissions, AUDIO_PERMISSION);
        }
        return;
      }
      voiceWorker.execute(() -> {
        try {
          Object value;
          switch (call.method) {
            case "initialize":
              value = NimzoVivox.initialize(this, call.argument("server"), (event, status, detail) -> {
                HashMap<String, Object> payload = new HashMap<>();
                payload.put("detail", detail);
                payload.put("status", status);
                runOnUiThread(() -> channel.invokeMethod(event, payload));
              });
              break;
            case "join": value = NimzoVivox.join(call.argument("loginToken"), call.argument("channelToken"), call.argument("channelUri")); break;
            case "setMic": value = NimzoVivox.setMic(Boolean.TRUE.equals(call.argument("enabled"))); break;
            case "setSpeaker": value = NimzoVivox.setSpeaker(Boolean.TRUE.equals(call.argument("enabled"))); break;
            case "leave": value = NimzoVivox.leave(); break;
            case "shutdown": NimzoVivox.shutdown(); value = 0; break;
            default: runOnUiThread(result::notImplemented); return;
          }
          Object response = value;
          runOnUiThread(() -> result.success(response));
        } catch (Throwable t) {
          runOnUiThread(() -> result.error("VIVOX_NATIVE", t.getMessage(), null));
        }
      });
    });
  }

  @Override
  public void onRequestPermissionsResult(int code, @NonNull String[] permissions, @NonNull int[] results) {
    super.onRequestPermissionsResult(code, permissions, results);
    if (code == AUDIO_PERMISSION && permissionResult != null) {
      permissionResult.success(checkSelfPermission(Manifest.permission.RECORD_AUDIO) == PackageManager.PERMISSION_GRANTED);
      permissionResult = null;
    }
  }

  @Override
  protected void onResume() {
    super.onResume();
    if (appUpdates != null) appUpdates.onResume();
  }

  @Override
  protected void onDestroy() {
    if (appUpdates != null) appUpdates.destroy();
    voiceWorker.execute(() -> { NimzoVivox.leave(); NimzoVivox.shutdown(); });
    voiceWorker.shutdown();
    if (permissionResult != null) { permissionResult.success(false); permissionResult = null; }
    super.onDestroy();
  }
}
