import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'services/app_config.dart';
import 'services/auth_callback.dart';
import 'services/auth_service.dart';
import 'services/admin_repository.dart';
import 'screens/auth_screen.dart';
import 'screens/admin_shell.dart';
import 'theme/admin_theme.dart';
import 'widgets/admin_widgets.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final passwordSetup = requestsPasswordSetup(Uri.base);
  final callbackError = initialAuthError(Uri.base);
  try {
    final config = AppConfig.fromEnvironment();
    await Supabase.initialize(
      url: config.url,
      publishableKey: config.publishableKey,
      debug: false,
      authOptions: FlutterAuthClientOptions(
        authFlowType: AuthFlowType.pkce,
        persistSession: false,
        // Surface rejected callbacks immediately, without an asynchronous
        // Auth stream error racing the first screen's subscription.
        detectSessionInUri: callbackError == null,
      ),
    );
    runApp(
      MainApp(
        service: AuthService(
          Supabase.instance.client,
          sameBrowserRedirect(Uri.base, config.redirectUrl),
        ),
        passwordSetup: passwordSetup,
        initialMessage: callbackError,
      ),
    );
  } catch (_) {
    runApp(const MainApp());
  }
}

class MainApp extends StatelessWidget {
  const MainApp({
    this.service,
    this.passwordSetup = false,
    this.initialMessage,
    super.key,
  });
  final AuthService? service;
  final bool passwordSetup;
  final String? initialMessage;
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'EnableWork+ Admin',
    debugShowCheckedModeBanner: false,
    theme: AdminTheme.light(),
    home: Scaffold(
      appBar: AppBar(title: const Text('EnableWork+ Admin')),
      body: SafeArea(
        child: service == null
            ? Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(28),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const AdminBrand(),
                            const SizedBox(height: 14),
                            Text(
                              'Connection configuration required',
                              style: Theme.of(context).textTheme.headlineSmall,
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Configure the approved EnableWork+ Supabase connection to enable administrator authentication. No preview records are shown.',
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              )
            : AuthScreen(
                service: service!,
                passwordSetup: passwordSetup,
                initialMessage: initialMessage,
                authenticatedBuilder: (context, signOut) => AdminShell(
                  onSignOut: signOut,
                  repository: AdminRepository(service!),
                ),
              ),
      ),
    ),
  );
}
