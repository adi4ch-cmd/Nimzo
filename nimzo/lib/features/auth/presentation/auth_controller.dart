import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../data/auth_repository.dart';
import '../data/auth_service.dart';
import '../domain/auth_user.dart';

final authRepositoryProvider = Provider(
    (ref) => AuthRepository(AuthService(Supabase.instance.client.auth)));

final authStateProvider = StreamProvider<AuthUser?>(
    (ref) => ref.watch(authRepositoryProvider).watch());

/// Status of the latest auth action (idle / loading / error).
class AuthController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  AuthRepository get _repo => ref.read(authRepositoryProvider);

  Future<void> _run(Future<void> Function() f) async {
    // OAuth is a single-flight operation. Starting Google/Facebook twice
    // before the first callback completes can invalidate the PKCE state and
    // produce "State has already been used".
    if (state.isLoading) return;
    state = const AsyncLoading();
    state = await AsyncValue.guard(f);
  }

  Future<void> google() => _run(_repo.signInWithGoogle);
  Future<void> facebook() => _run(_repo.signInWithFacebook);
  Future<void> signIn(String e, String p) =>
      _run(() => _repo.signInWithEmail(e, p));
  Future<void> signUp(String e, String p) =>
      _run(() => _repo.signUpWithEmail(e, p));
  Future<void> reset(String e) => _run(() => _repo.resetPassword(e));
  Future<void> signOut() => _run(_repo.signOut);
}

final authControllerProvider =
    AsyncNotifierProvider<AuthController, void>(AuthController.new);
