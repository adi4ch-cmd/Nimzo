# NIMZO Android release startup fix — verified from emulator crash log.
#
# The plugin's native JNI bridge resolves this exact JVM signature:
# SharedPreferencesApiRegistrar.getAll(String,List,kotlin.coroutines.Continuation)
# -> java.lang.Object
#
# R8 had renamed kotlin.coroutines.Continuation to Lh4/c; in the APK, so
# the native lookup threw NoSuchMethodError before Supabase could load.
# Keep the original Kotlin Continuation ABI and both plugin API registrars.
# Additional verified emulator blocker: reflection also loads kotlin.Result;
# without this, R8 removes/renames the Kotlin runtime type completely.
-keep class kotlin.** { *; }
-keep interface kotlin.** { *; }
-keep class kotlin.coroutines.** { *; }
-keep class io.flutter.plugins.sharedpreferences.** { *; }

# Preserve native/JNI-visible annotations and method descriptors.
-keepattributes Signature,InnerClasses,EnclosingMethod,RuntimeVisibleAnnotations
