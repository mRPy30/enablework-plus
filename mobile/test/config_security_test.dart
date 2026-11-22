import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:enablework_plus/services/app_config.dart';
import 'package:enablework_plus/models/account_profile.dart';

void main() {
  const endpoint = 'http://127.0.0.1:54321';
  const callback = 'com.enableworkplus.app://auth/callback';
  // Deliberately fake keys; tests perform no network requests.
  const publicTestKey = 'sb_publishable_dummy_not_a_real_key';
  test('approved local public configuration is accepted', () {
    final config = AppConfig.validate(endpoint, publicTestKey, callback);
    expect(config.url, endpoint);
    expect(config.redirectUrl, callback);
  });
  test('only the approved HTTPS hosted project is accepted', () {
    const hosted = 'https://kqcbitrjvucsfkmwkwmj.supabase.co';
    expect(AppConfig.validate(hosted, publicTestKey, callback).url, hosted);
    for (final url in [
      'http://kqcbitrjvucsfkmwkwmj.supabase.co',
      '$hosted.evil.test',
      '$hosted:8443',
      '$hosted/rest/v1',
      '$hosted?key=value',
      '$hosted#fragment',
      'https://user@kqcbitrjvucsfkmwkwmj.supabase.co',
    ]) {
      expect(
        () => AppConfig.validate(url, publicTestKey, callback),
        throwsFormatException,
      );
    }
  });
  test('unapproved endpoints are rejected', () {
    expect(
      () => AppConfig.validate(
        'https://example.supabase.co',
        publicTestKey,
        callback,
      ),
      throwsFormatException,
    );
    expect(
      () =>
          AppConfig.validate('http://127.0.0.1:1234', publicTestKey, callback),
      throwsFormatException,
    );
    expect(
      () => AppConfig.validate(
        'http://127.0.0.1:54321@evil.test',
        publicTestKey,
        callback,
      ),
      throwsFormatException,
    );
  });
  test('secret and legacy privileged keys are rejected', () {
    expect(
      () => AppConfig.validate(
        endpoint,
        'sb_secret_dummy_not_a_real_key',
        callback,
      ),
      throwsFormatException,
    );
    final payload = base64Url
        .encode(utf8.encode('{"role":"service_role"}'))
        .replaceAll('=', '');
    expect(
      () => AppConfig.validate(endpoint, 'eyJdummy.$payload.fake', callback),
      throwsFormatException,
    );
  });
  test('unexpected callback cannot receive recovery sessions', () {
    expect(
      () => AppConfig.validate(endpoint, publicTestKey, 'https://evil.test/'),
      throwsFormatException,
    );
  });
  test('unknown roles and suspended profiles fail closed', () {
    expect(
      () => AccountProfile.fromJson({
        'role': 'employer',
        'account_status': 'active',
      }),
      throwsStateError,
    );
    expect(
      () => AccountProfile.fromJson({
        'role': 'system_administrator',
        'account_status': 'suspended',
      }),
      throwsStateError,
    );
  });
}
