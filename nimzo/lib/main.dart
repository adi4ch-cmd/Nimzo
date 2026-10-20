import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app/app.dart';
import 'core/services/firebase_push_service.dart';
import 'core/constants/app_constants.dart';
import 'core/services/nimzo_native_session_storage.dart';

/// First Flutter frame must never wait for network or optional FCM plugins.
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const NimzoBootstrapApp());
}

class NimzoBootstrapApp extends StatefulWidget {
  const NimzoBootstrapApp({super.key});
  @override
  State<NimzoBootstrapApp> createState() => _NimzoBootstrapAppState();
}

class _NimzoBootstrapAppState extends State<NimzoBootstrapApp> {
  ProviderContainer? _container;
  bool _starting = true;
  String? _startupError;
  String _startupStage = 'android-storage';
  // Reuse the in-flight future after a startup timeout: repeated tapping
  // Retry must not initialize the Supabase singleton concurrently.
  Future<Supabase>? _supabaseInitialization;

  String _safeStartupMessage(Object error) {
    if (error is TimeoutException) {
      return 'Startup is taking too long. Tap Retry after a moment.';
    }
    if (error is PlatformException) {
      // The exception CODE can distinguish missing Android plugin channels
      // from bad/locked Android storage, without leaking private SDK messages.
      final code = error.code
          .replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '')
          .toLowerCase();
      final safeCode = code.isEmpty
          ? 'unknown'
          : code.substring(0, code.length > 48 ? 48 : code.length);
      return 'NIMZO Android startup error ($_startupStage/$safeCode). '
          'Try Retry. Screenshot this exact code if it continues.';
    }
    // Never display exception.message/details: they may contain session data.
    return 'NIMZO initialization error (${error.runtimeType}). Tap Retry.';
  }

  @override
  void initState() {
    super.initState();
    unawaited(_initializeApp());
  }

  Future<void> _initializeApp() async {
    try {
      // Probe Android session storage first to identify plugin failures.
      // Reading preferences must not clear or replace existing login data.
      _startupStage = 'android-storage';
      LocalStorage? recoveredStorage;
      GotrueAsyncStorage? recoveredPkceStorage;
      try {
        await SharedPreferences.getInstance()
            .timeout(const Duration(seconds: 8));
      } on PlatformException {
        if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) rethrow;
        // Flutter's Pigeon SharedPreferences channel failed. Preserve existing
        // session/PKCE values by using the same Android preferences file.
        _startupStage = 'android-native-storage';
        final key = 'sb-${Uri.parse(AppConstants.supabaseUrl).host.split('.').first}-auth-token';
        final native = NimzoNativeSessionStorage(persistSessionKey: key);
        await native.initialize().timeout(const Duration(seconds: 8));
        recoveredStorage = native;
        recoveredPkceStorage = NimzoNativePkceStorage();
        debugPrint('NIMZO recovered Android auth storage using native bridge');
      }
      // Preserve PKCE, existing session storage and OAuth callback handling.
      _startupStage = 'supabase-auth';
      await (_supabaseInitialization ??= Supabase.initialize(
        url: AppConstants.supabaseUrl,
        publishableKey: AppConstants.supabaseAnonKey,
        authOptions: FlutterAuthClientOptions(
          authFlowType: AuthFlowType.pkce,
          localStorage: recoveredStorage,
          pkceAsyncStorage: recoveredPkceStorage,
        ),
      )).timeout(const Duration(seconds: 12));
      if (!mounted) return;
      final container = ProviderContainer();
      _container = container;
      setState(() {
        _starting = false;
        _startupError = null;
      });
      // FCM can take arbitrarily long; it must never delay the login screen.
      unawaited(_initializePush(container));
    } catch (error) {
      // A genuine failure must be retryable. Keep the same in-flight future
      // only while timeout has left initialization running in the background.
      if (error is! TimeoutException) {
        _supabaseInitialization = null;
      }
      final safeCode = error is PlatformException
          ? error.code.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '')
          : error.runtimeType.toString();
      debugPrint('NIMZO startup failed stage=$_startupStage code=$safeCode');
      if (!mounted) return;
      setState(() {
        _starting = false;
        _startupError = _safeStartupMessage(error);
      });
    }
  }

  Future<void> _initializePush(ProviderContainer container) async {
    try {
      final gateway = await initializeFirebasePush()
          .timeout(const Duration(seconds: 8));
      if (!mounted || gateway == null) return;
      container.read(pushGatewayStateProvider.notifier).state = gateway;
    } catch (error) {
      debugPrint('Optional NIMZO push unavailable: ${error.runtimeType}');
    }
  }

  void _retry() {
    if (_starting) return;
    setState(() {
      _starting = true;
      _startupError = null;
    });
    unawaited(_initializeApp());
  }

  @override
  void dispose() {
    _container?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final container = _container;
    if (container != null) {
      return UncontrolledProviderScope(
        container: container,
        child: const NimzoApp(),
      );
    }
    return MaterialApp(
      title: 'NIMZO',
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: const Color(0xffeeeaff),
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.mic_rounded,
                    size: 65, color: Color(0xff7439d4)),
                  const SizedBox(height: 14),
                  const Text('NIMZO', style: TextStyle(
                    fontSize: 28, letterSpacing: 4,
                    fontWeight: FontWeight.w800, color: Color(0xff291548))),
                  const SizedBox(height: 24),
                  if (_starting)
                    const CircularProgressIndicator()
                  else ...[
                    Text(_startupError ?? 'Starting NIMZO...',
                      textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    FilledButton(onPressed: _retry, child: const Text('Retry')),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
