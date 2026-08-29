import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  const AuthService(this._client);

  final SupabaseClient _client;

  Future<void> signIn(String email, String password) async {
    await _client.auth.signInWithPassword(email: email, password: password);
  }

  Future<AuthResponse> createAccount(String email, String password) {
    return _client.auth.signUp(email: email, password: password);
  }

  Future<void> sendEmailOtp(String email) =>
      _client.auth.signInWithOtp(email: email, shouldCreateUser: true);

  Future<AuthResponse> verifyEmailOtp(String email, String code) =>
      _client.auth.verifyOTP(
        email: email,
        token: code,
        type: OtpType.magiclink,
      );

  Future<void> setStaffPassword(String password) async {
    final metadata = Map<String, dynamic>.from(
      _client.auth.currentUser?.userMetadata ?? const {},
    );
    metadata['staff_password_setup_complete'] = true;
    await _client.auth.updateUser(
      UserAttributes(
        password: password,
        data: metadata,
      ),
    );
  }

  Future<void> signOut() => _client.auth.signOut();
}
