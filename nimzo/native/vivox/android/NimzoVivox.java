package io.nimzo.vivox;

import android.content.Context;
import android.util.Log;
import com.vivox.sdk.JniHelpers;

public final class NimzoVivox {
  static {
    System.loadLibrary("vivox_bridge");
  }

  public interface Listener {
    void onVivoxEvent(String event, int status, String detail);
  }

  private NimzoVivox() {}

  public static boolean initialize(Context context, String accountManagementServer, Listener listener) {
    if (!JniHelpers.init(context)) {
      Log.e("NimzoVivox", "JniHelpers.init failed");
      return false;
    }
    return nativeInit(listener, accountManagementServer);
  }

  public static int join(String loginToken, String channelToken, String channelUri) {
    return nativeLoginAndJoin(loginToken, channelToken, channelUri);
  }

  public static int setMic(boolean enabled) { return nativeSetMic(enabled); }
  public static int setSpeaker(boolean enabled) { return nativeSetSpeaker(enabled); }
  public static int leave() { return nativeLeave(); }
  public static void shutdown() { nativeShutdown(); }

  private static native boolean nativeInit(Listener listener, String server);
  private static native int nativeLoginAndJoin(String loginToken, String channelToken, String channelUri);
  private static native int nativeSetMic(boolean enabled);
  private static native int nativeSetSpeaker(boolean enabled);
  private static native int nativeLeave();
  private static native void nativeShutdown();
}
