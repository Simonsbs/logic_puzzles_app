class AppConfig {
  const AppConfig({
    required this.supabaseUrl,
    required this.supabaseAnonKey,
    required this.supabaseAuthRedirectUrl,
  });

  final String supabaseUrl;
  final String supabaseAnonKey;
  final String supabaseAuthRedirectUrl;

  bool get supabaseEnabled => supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;

  static AppConfig fromEnvironment() {
    return const AppConfig(
      supabaseUrl: String.fromEnvironment('SUPABASE_URL', defaultValue: ''),
      supabaseAnonKey: String.fromEnvironment('SUPABASE_ANON_KEY', defaultValue: ''),
      supabaseAuthRedirectUrl: String.fromEnvironment(
        'SUPABASE_AUTH_REDIRECT_URL',
        defaultValue: 'com.simonsbs.logicpuzzles://login-callback/',
      ),
    );
  }
}
