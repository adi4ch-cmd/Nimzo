# Nimzo

Flutter Android social voice-room app backed by Supabase and a native Vivox bridge.

The latest application work is on the repair branches; main contains an older scaffold. Preserve the deployed VIP/SVIP retirement when integrating branches.

## Verification

Use Flutter 3.47.x, the committed pubspec.lock, and Java 17.

```sh
flutter pub get --enforce-lockfile
flutter analyze
flutter test
```

From the repository root, run Python unittest discovery in tools/tests, nimzo/test/voice, nimzo/test/update and nimzo/test/reference, plus the Node tests under both Supabase Edge Functions. The update tests require javac.

## Android

The complete build recipe is .github/workflows/nimzo-apk-build.yml. Generating the default Flutter Android platform alone does not install the native voice bridge, updater, permissions or OAuth callback. Follow its native installation and manifest configuration steps, and run tools/configure_android_gradle.py after generating Android. It pins AGP 8.11.1, Kotlin 2.2.20 and Gradle 8.14.3, applies Kotlin for templates that omit it, and limits Gradle memory/workers for common CI environments. The workflow verifies the Vivox SDK download by SHA-256.

The permanent signing identity is external to Git. Without that identity, the workflow creates a clearly identified test APK. It must not enter the permanent automatic-update channel. An installation with a different certificate cannot accept it as an update.

## Supabase

Client configuration is in lib/core/constants/app_constants.dart. Only public client keys belong in an APK; server/provider credentials remain in Edge Function secrets. Root-level supabase/migrations records current production repairs. The nested nimzo/supabase directory is historical scaffolding and is not a complete fresh-database setup.

Google/Facebook OAuth, two-device voice and real Google Play purchases require configured external providers and physical-device verification. Additional games and Task rewards need defined server rules; disabled entries must not invent settlements or rewards.
