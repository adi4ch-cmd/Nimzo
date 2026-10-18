import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app/app.dart';
import 'core/services/firebase_push_service.dart';
import 'core/constants/app_constants.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Supabase Auth uses PKCE for mobile deep-link OAuth. The SDK owns the
  // callback/code exchange; do not manually exchange the callback code.
  await Supabase.initialize(
    url: AppConstants.supabaseUrl,
    publishableKey: AppConstants.supabaseAnonKey,
    authOptions: const FlutterAuthClientOptions(
      authFlowType: AuthFlowType.pkce,
    ),
  );

  final push = await initializeFirebasePush();
  runApp(ProviderScope(
    overrides: [pushGatewayProvider.overrideWithValue(push)],
    child: const NimzoApp(),
  ));
}
