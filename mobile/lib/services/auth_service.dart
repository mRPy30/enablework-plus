import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/account_profile.dart';

class AuthService {
  AuthService(this.client, this.redirectUrl);
  final SupabaseClient client;
  final String redirectUrl;
  String? get userId => client.auth.currentUser?.id;
  bool get hasSession => client.auth.currentSession != null;
  Stream<AuthState> get authChanges => client.auth.onAuthStateChange;
  static const expectedRole = AppRole.jobSeeker;

  Future<AccountProfile> requireAccess() async {
    final id = client.auth.currentUser?.id;
    if (id == null) throw StateError('Sign in required');
    // RLS filters suspended accounts. Do not trust user metadata or decoded JWT roles.
    final row = await client
        .from('profiles')
        .select('role,account_status')
        .eq('id', id)
        .maybeSingle();
    if (row == null) throw StateError('Account unavailable');
    final profile = AccountProfile.fromJson(row);
    if (profile.role != expectedRole) throw StateError('Account unavailable');
    return profile;
  }

  Future<void> signIn(String email, String password) async {
    await client.auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );
    try {
      await requireAccess();
    } catch (_) {
      await signOut();
      rethrow;
    }
  }

  Future<void> signUp(String email, String password, String fullName) async {
    await client.auth.signUp(
      email: email.trim(),
      password: password,
      emailRedirectTo: redirectUrl,
      data: {'full_name': fullName.trim()},
    );
  }

  Future<void> requestPasswordReset(String email) =>
      client.auth.resetPasswordForEmail(email.trim(), redirectTo: redirectUrl);

  Future<void> updatePassword(String password) async {
    await requireAccess();
    await client.auth.updateUser(UserAttributes(password: password));
  }

  Future<void> signOut() => client.auth.signOut(scope: SignOutScope.local);
}
