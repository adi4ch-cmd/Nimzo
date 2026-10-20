import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app/app.dart';
import 'core/services/firebase_push_service.dart';
import 'core/constants/app_constants.dart';

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
  // Reuse the in-flight future after a startup timeout: repeated tapping
  // Retry must not initialize the Supabase singleton concurrently.
  Future<Supabase>? _supabaseInitialization;

  String _safeStartupMessage(Object error) {
    if (error is TimeoutException) {
      return 'Startup is taking too long. Tap Retry after a moment.';
    }
    // Only a sanitized error TYPE is displayed; never show OAuth tokens,
    // Supabase URLs, exception messages or local session contents.
    return 'NIMZO initialization error (${error.runtimeType}). Tap Retry.';
  }

  @override
  void initState() {
    super.initState();
    unawaited(_initializeApp());
  }

  Future<void> _initializeApp() async {
    try {
      // Preserve PKCE, existing session storage and OAuth callback handling.
      await (_supabaseInitialization ??= Supabase.initialize(
        url: AppConstants.supabaseUrl,
        publishableKey: AppConstants.supabaseAnonKey,
        authOptions: const FlutterAuthClientOptions(
          authFlowType: AuthFlowType.pkce,
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
      debugPrint('NIMZO startup failed: ${error.runtimeType}');
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
