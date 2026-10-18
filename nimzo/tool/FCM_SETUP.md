# NIMZO Android Firebase Cloud Messaging setup

NIMZO uses Supabase for authentication and database, Vivox for voice and Firebase only for push notifications.

The app already contains `firebase_core`, `firebase_messaging` and `firebase_push_service.dart`. The `nimzo/android/` directory is ignored by Git and regenerated in the APK workflow. Copying a JSON file there on one computer does **not** configure CI builds.

## Enable push in APK builds

In the repository open **Settings → Secrets and variables → Actions → New repository secret**.

Create the secret named **`NIMZO_GOOGLE_SERVICES_JSON`** and paste the full *Android* `google-services.json` downloaded from Firebase project `nimzo-1f296` for package `io.nimzo.app`.

The Android workflow then runs `nimzo/tool/configure_fcm_android.py` after generating the Flutter platform. This applies the Google Services Gradle plugin, corrects the Android package and MainActivity, adds Android 13+ notification permission and saves the JSON at `android/app/google-services.json`. The JSON itself is **not committed** to this public repository.

For local builds, after running `flutter create --platforms=android --project-name nimzo .`, run:

```sh
python3 nimzo/tool/configure_fcm_android.py --root nimzo --config-file /secure/path/google-services.json
cd nimzo && flutter pub get && flutter build apk --release
```

## Still necessary before notifications work end-to-end

- Test on a real Android phone after granting notification permission, verifying FCM token registration through the existing Supabase `register_device` RPC and checking delivery.
- Server-side notifications require a trusted sender (e.g. Supabase Edge Function with Firebase Admin credentials) that uses FCM HTTP v1. **Do not commit Firebase service-account JSON to GitHub.**
- iOS requires its own Firebase iOS app config, APNs credentials/capability and Xcode integration. This Android JSON does not configure iOS.
- FCM configuration is not Firebase Authentication. Supabase and Vivox are unchanged.

If the Actions secret has not been configured, the current workflow builds without this Firebase Android provisioning and prints a warning.
