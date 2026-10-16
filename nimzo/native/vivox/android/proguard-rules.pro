# vivox_bridge.cpp resolves this callback with GetMethodID, which R8 cannot see.
# Retain the interface and each concrete callback implementation and method name.
-keep interface io.nimzo.vivox.NimzoVivox$Listener {
    public void onVivoxEvent(java.lang.String, int, java.lang.String);
}
-keep class * implements io.nimzo.vivox.NimzoVivox$Listener {
    public void onVivoxEvent(java.lang.String, int, java.lang.String);
}
