import 'package:enablework_admin/services/auth_callback.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('expired callback is surfaced before auth listeners start', () {
    expect(
      initialAuthError(
        Uri.parse(
          'http://127.0.0.1:3000/?error=access_denied&error_code=otp_expired&error_description=private',
        ),
      ),
      contains('expired'),
    );
    expect(
      initialAuthError(
        Uri.parse('http://localhost:3000/#error_code=otp_expired'),
      ),
      isNot(contains('private')),
    );
    expect(
      initialAuthError(Uri.parse('http://localhost:3000/#type=invite')),
      isNull,
    );
  });
  test('invitation and recovery callbacks request password setup', () {
    expect(
      requestsPasswordSetup(Uri.parse('http://localhost:3000/#type=invite')),
      isTrue,
    );
    expect(
      requestsPasswordSetup(Uri.parse('http://localhost:3000/?type=recovery')),
      isTrue,
    );
    expect(requestsPasswordSetup(Uri.parse('http://localhost:3000/')), isFalse);
    expect(
      requestsPasswordSetup(Uri.parse('http://localhost:3000/#type=signup')),
      isFalse,
    );
  });
  test('PKCE recovery keeps the same approved browser origin', () {
    const fallback = 'http://127.0.0.1:3000/';
    expect(
      sameBrowserRedirect(Uri.parse('http://localhost:3000/'), fallback),
      'http://localhost:3000/',
    );
    expect(
      sameBrowserRedirect(Uri.parse('https://evil.example/'), fallback),
      fallback,
    );
    expect(
      sameBrowserRedirect(Uri.parse('http://localhost:4000/'), fallback),
      fallback,
    );
  });
  test('errors explain recovery without disclosing provider payloads', () {
    expect(
      authFailureMessage(
        const AuthException('sensitive detail', code: 'otp_expired'),
      ),
      contains('Forgot password'),
    );
    expect(
      authFailureMessage(Exception('token=secret')),
      isNot(contains('secret')),
    );
    expect(
      authFailureMessage(
        const AuthException('private', code: 'invalid_credentials'),
      ),
      contains('incorrect'),
    );
  });
}
