package io.nimzo.app;

import android.os.Bundle;
import androidx.annotation.NonNull;
import io.flutter.embedding.android.FlutterActivity;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.plugin.common.MethodChannel;
import io.nimzo.vivox.NimzoVivox;

public class MainActivity extends FlutterActivity {
  private static final String CHANNEL = "nimzo/vivox";

  @Override
  public void configureFlutterEngine(@NonNull FlutterEngine flutterEngine) {
    super.configureFlutterEngine(flutterEngine);
    MethodChannel channel = new MethodChannel(
        flutterEngine.getDartExecutor().getBinaryMessenger(), CHANNEL);

    channel.setMethodCallHandler((call, result) -> {
      try {
        switch (call.method) {
          case "initialize": {
            String server = call.argument("server");
            boolean ok = NimzoVivox.initialize(this, server, (event, status, detail) ->
                runOnUiThread(() -> channel.invokeMethod(
                    event, java.util.Collections.singletonMap("detail", detail))));
            result.success(ok);
            break;
          }
          case "join": {
            String loginToken = call.argument("loginToken");
            String channelToken = call.argument("channelToken");
            String channelUri = call.argument("channelUri");
            result.success(NimzoVivox.join(loginToken, channelToken, channelUri));
            break;
          }
          case "setMic":
            result.success(NimzoVivox.setMic(Boolean.TRUE.equals(call.argument("enabled"))));
            break;
          case "setSpeaker":
            result.success(NimzoVivox.setSpeaker(Boolean.TRUE.equals(call.argument("enabled"))));
            break;
          case "leave":
            result.success(NimzoVivox.leave());
            break;
          case "shutdown":
            NimzoVivox.shutdown();
            result.success(0);
            break;
          default:
            result.notImplemented();
        }
      } catch (Throwable t) {
        result.error("VIVOX_NATIVE", t.getMessage(), null);
      }
    });
  }

  @Override
  protected void onDestroy() {
    NimzoVivox.shutdown();
    super.onDestroy();
  }
}
