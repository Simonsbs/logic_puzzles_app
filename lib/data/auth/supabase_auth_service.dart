import 'package:flutter/foundation.dart';
import 'package:logic_puzzles_app/core/services/auth_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthUser;

class SupabaseAuthService implements AuthService {
  SupabaseAuthService({
    required SupabaseClient client,
    required String redirectUrl,
  })  : _client = client,
        _redirectUrl = redirectUrl;

  final SupabaseClient _client;
  final String _redirectUrl;

  @override
  Stream<AuthUser?> authStateChanges() async* {
    yield currentUser;
    yield* _client.auth.onAuthStateChange.map(
      (event) => _mapUser(event.session?.user),
    );
  }

  @override
  AuthUser? get currentUser => _mapUser(_client.auth.currentUser);

  @override
  Future<AuthUser?> signInWithGoogle() async {
    final isMobile = !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS);
    if (!isMobile) {
      throw UnsupportedError(
        'Google sign-in callback is configured for mobile app deep links. '
        'Run this on Android/iOS for full OAuth flow.',
      );
    }

    await _client.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: _redirectUrl,
    );
    return currentUser;
  }

  @override
  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  AuthUser? _mapUser(User? user) {
    if (user == null) {
      return null;
    }

    return AuthUser(
      id: user.id,
      displayName: user.userMetadata?['full_name'] as String? ?? 'Player',
      email: user.email ?? '',
    );
  }
}
