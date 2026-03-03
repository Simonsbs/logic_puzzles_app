abstract class AuthService {
  Stream<AuthUser?> authStateChanges();
  Future<AuthUser?> signInWithGoogle();
  Future<void> signOut();
  AuthUser? get currentUser;
}

class AuthUser {
  const AuthUser({required this.id, required this.displayName, required this.email});

  final String id;
  final String displayName;
  final String email;
}
