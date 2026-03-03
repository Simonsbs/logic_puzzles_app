import 'dart:async';

import 'package:logic_puzzles_app/core/services/auth_service.dart';

class LocalAuthService implements AuthService {
  final _controller = StreamController<AuthUser?>.broadcast();
  AuthUser? _currentUser;

  @override
  Stream<AuthUser?> authStateChanges() => _controller.stream;

  @override
  AuthUser? get currentUser => _currentUser;

  @override
  Future<AuthUser?> signInWithGoogle() async {
    _currentUser = const AuthUser(
      id: 'guest-local',
      displayName: 'Guest Player',
      email: 'guest@local',
      avatarUrl: null,
    );
    _controller.add(_currentUser);
    return _currentUser;
  }

  @override
  Future<void> signOut() async {
    _currentUser = null;
    _controller.add(null);
  }

  @override
  Future<void> deleteAccount() async {
    await signOut();
  }
}
