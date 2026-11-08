import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:enablework_admin/screens/auth_screen.dart';
import 'package:enablework_admin/services/auth_service.dart';
import 'package:enablework_admin/models/account_profile.dart';

// No actual client, network requests, background isolates or credentials.
class SignedOutAuthService implements AuthService {
  @override
  SupabaseClient get client => throw UnimplementedError();
  @override
  String get redirectUrl => 'http://127.0.0.1:3000/';
  @override
  bool get hasSession => false;
  @override
  Stream<AuthState> get authChanges => const Stream.empty();
  @override
  Future<AccountProfile> requireAccess() async =>
      throw StateError('Signed out');
  @override
  Future<void> signIn(String email, String password) async {}
  @override
  Future<void> signOut() async {}
  @override
  Future<void> requestPasswordReset(String email) async {}
  @override
  Future<void> updatePassword(String password) async {}
}

void main() {
  testWidgets('role-specific authentication actions match the approved role', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: AuthScreen(service: SignedOutAuthService())),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Sign in'), findsOneWidget);
    expect(find.text('Register as a job seeker'), findsNothing);
    expect(find.text('System Administrator'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
