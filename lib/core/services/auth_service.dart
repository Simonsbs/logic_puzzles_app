abstract class AuthService {
  Stream<AuthUser?> authStateChanges();
  Future<AuthUser?> signInWithGoogle();
  Future<void> signOut();
  Future<void> deleteAccount();
  AuthUser? get currentUser;
}

class AuthUser {
  const AuthUser({
    required this.id,
    required this.displayName,
    required this.email,
    this.avatarUrl,
  });

  final String id;
  final String displayName;
  final String email;
  final String? avatarUrl;
}
