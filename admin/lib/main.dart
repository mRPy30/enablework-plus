import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'services/app_config.dart';
import 'services/auth_service.dart';
import 'screens/auth_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    final config = AppConfig.fromEnvironment();
    await Supabase.initialize(
      url: config.url,
      publishableKey: config.publishableKey,
      debug: false,
      authOptions: const FlutterAuthClientOptions(
        authFlowType: AuthFlowType.pkce,
        persistSession: false,
      ),
    );
    runApp(
      MainApp(
        service: AuthService(Supabase.instance.client, config.redirectUrl),
      ),
    );
  } catch (_) {
    runApp(const MainApp());
  }
}

class MainApp extends StatelessWidget {
  const MainApp({this.service, super.key});
  final AuthService? service;
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'EnableWork+ Admin',
    theme: ThemeData(colorSchemeSeed: Colors.teal, useMaterial3: true),
    home: Scaffold(
      appBar: AppBar(title: const Text('EnableWork+ Admin')),
      body: SafeArea(
        child: service == null
            ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'Configure the local Supabase connection to enable authentication. See docs/phase-1-local-setup.md.',
                  ),
                ),
              )
            : AuthScreen(service: service!),
      ),
    ),
  );
}
