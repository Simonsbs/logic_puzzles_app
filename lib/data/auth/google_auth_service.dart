import 'dart:async';

import 'package:google_sign_in/google_sign_in.dart';
import 'package:logic_puzzles_app/core/services/auth_service.dart';

class GoogleAuthService implements AuthService {
  GoogleAuthService() {
    _googleSignIn.onCurrentUserChanged.listen((account) {
      _currentUser = account == null
          ? null
          : AuthUser(
              id: account.id,
              displayName: account.displayName ?? 'Player',
              email: account.email,
            );
      _controller.add(_currentUser);
    });
  }

  final _googleSignIn = GoogleSignIn.standard(scopes: <String>['email']);
  final _controller = StreamController<AuthUser?>.broadcast();
  AuthUser? _currentUser;

  @override
  AuthUser? get currentUser => _currentUser;

  @override
  Stream<AuthUser?> authStateChanges() => _controller.stream;

  @override
  Future<AuthUser?> signInWithGoogle() async {
    final account = await _googleSignIn.signIn();
    if (account == null) {
      return null;
    }

    _currentUser = AuthUser(
      id: account.id,
      displayName: account.displayName ?? 'Player',
      email: account.email,
    );
    _controller.add(_currentUser);
    return _currentUser;
  }

  @override
  Future<void> signOut() async {
    await _googleSignIn.signOut();
    _currentUser = null;
    _controller.add(null);
  }
}
