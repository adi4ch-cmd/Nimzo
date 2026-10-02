import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

/// Firebase is used ONLY for FCM + Crashlytics (+ analytics/app check/perf/distribution).
/// No Firestore, Realtime DB or Storage.
class FirebaseService {
  static Future<void> init() async {
    await Firebase.initializeApp();
    FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
    PlatformDispatcher.instance.onError = (e, s) {
      FirebaseCrashlytics.instance.recordError(e, s, fatal: true);
      return true;
    };
    await FirebaseMessaging.instance.requestPermission();
  }

  /// Send this token to Supabase (device_tokens table) so the server can push.
  static Future<String?> fcmToken() => FirebaseMessaging.instance.getToken();
}
