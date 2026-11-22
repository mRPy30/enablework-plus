import 'package:supabase_flutter/supabase_flutter.dart';

String? initialAuthError(Uri uri) {
  try {
    final values = {
      ...uri.queryParameters,
      ...Uri.splitQueryString(uri.fragment),
    };
    if (!values.containsKey('error') && !values.containsKey('error_code')) {
      return null;
    }
    return authFailureMessage(
      AuthException(
        'Authentication callback failed',
        code: values['error_code'] ?? values['error'],
      ),
    );
  } on FormatException {
    return 'This sign-in link is invalid. Request a fresh link using Forgot password.';
  }
}

// This URL hint selects UI only. A verified session and server-side admin role
// are still required before changing a password or opening the console.
bool requestsPasswordSetup(Uri uri) {
  try {
    final fragment = Uri.splitQueryString(uri.fragment);
    final type = fragment['type'] ?? uri.queryParameters['type'];
    return type == 'invite' || type == 'recovery';
  } on FormatException {
    return false;
  }
}

String authFailureMessage(Object error) {
  if (error is AuthException) {
    if (error.code == 'weak_password') {
      return 'Use a password with at least 12 characters that meets the account password policy.';
    }
    if (error.code == 'otp_expired' || error.code == 'access_denied') {
      return 'This email link has expired or has already been used. Enter your administrator email and choose Forgot password to request a fresh link.';
    }
    if (error.code == 'invalid_credentials') {
      return 'The email or password is incorrect. If you have not set a password yet, choose Forgot password.';
    }
    if (error.code == 'over_email_send_rate_limit' ||
        error.statusCode == '429') {
      return 'Too many email requests. Please wait before requesting another link.';
    }
  }
  return 'We could not verify your session. Check your connection. For an invitation or password reset, request a fresh link using Forgot password and open it in this same browser.';
}

String sameBrowserRedirect(Uri uri, String fallback) {
  if (uri.scheme == 'http' &&
      const ['localhost', '127.0.0.1'].contains(uri.host) &&
      uri.port == 3000 &&
      uri.userInfo.isEmpty) {
    return '${uri.origin}/';
  }
  return fallback;
}
