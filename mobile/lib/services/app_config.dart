import 'dart:convert';

/// Approved local/hosted endpoints. Only public client keys belong here.
class AppConfig {
  const AppConfig({
    required this.url,
    required this.publishableKey,
    required this.redirectUrl,
  });
  final String url;
  final String publishableKey;
  final String redirectUrl;

  static AppConfig fromEnvironment() => validate(
    const String.fromEnvironment('SUPABASE_URL'),
    const String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY'),
    const String.fromEnvironment('AUTH_REDIRECT_URL'),
  );

  static AppConfig validate(String url, String key, String redirect) {
    final endpoint = Uri.tryParse(url);
    final approvedHosted =
        endpoint?.scheme == 'https' &&
        endpoint?.host == 'kqcbitrjvucsfkmwkwmj.supabase.co' &&
        endpoint?.port == 443;
    final approvedLocal =
        endpoint?.scheme == 'http' &&
        const [
          '127.0.0.1',
          'localhost',
          '10.0.2.2',
          '::1',
        ].contains(endpoint?.host) &&
        endpoint?.port == 54321;
    if (endpoint == null ||
        !(approvedHosted || approvedLocal) ||
        endpoint.userInfo.isNotEmpty ||
        endpoint.hasQuery ||
        endpoint.hasFragment ||
        !const ['', '/'].contains(endpoint.path)) {
      throw const FormatException(
        'Use the approved EnableWork+ Supabase endpoint.',
      );
    }
    if (key.isEmpty || key.contains('YOUR_') || key.startsWith('sb_secret_')) {
      throw const FormatException('A public client key is required.');
    }
    // Defense against accidentally packaging legacy service-role JWTs. Never use
    // decoded client claims to authorize a user; database RLS is authoritative.
    if (key.startsWith('eyJ')) {
      try {
        final claims = jsonDecode(
          utf8.decode(base64Url.decode(base64Url.normalize(key.split('.')[1]))),
        );
        if (claims is! Map || claims['role'] != 'anon') {
          throw const FormatException();
        }
      } catch (_) {
        throw const FormatException('Only a public client key is allowed.');
      }
    } else if (!key.startsWith('sb_publishable_')) {
      throw const FormatException('Only a public client key is allowed.');
    }
    const allowedRedirects = ['com.enableworkplus.app://auth/callback'];
    if (!allowedRedirects.contains(redirect)) {
      throw const FormatException(
        'Use an explicitly configured local Auth callback.',
      );
    }
    return AppConfig(url: url, publishableKey: key, redirectUrl: redirect);
  }
}
