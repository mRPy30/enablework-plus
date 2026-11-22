import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'models/seeker_workspace.dart';
import 'services/app_config.dart';
import 'services/auth_service.dart';
import 'services/secure_auth_storage.dart';
import 'services/seeker_repository.dart';
import 'screens/auth_screen.dart';
import 'screens/seeker_home.dart';
import 'utils/preference_text_scaler.dart';
import 'widgets/brand_identity.dart';
import 'theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const _BootstrapApp());
}

class _BootstrapApp extends StatefulWidget {
  const _BootstrapApp();

  @override
  State<_BootstrapApp> createState() => _BootstrapAppState();
}

class _BootstrapAppState extends State<_BootstrapApp> {
  late final Future<AuthService?> _service = _initialize();

  Future<AuthService?> _initialize() async {
    try {
      final config = AppConfig.fromEnvironment();
      await Supabase.initialize(
        url: config.url,
        publishableKey: config.publishableKey,
        debug: false,
        authOptions: FlutterAuthClientOptions(
          authFlowType: AuthFlowType.pkce,
          localStorage: SecureAuthStorage(config.url),
        ),
      );
      return AuthService(Supabase.instance.client, config.redirectUrl);
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<AuthService?>(
    future: _service,
    builder: (context, snapshot) =>
        snapshot.connectionState == ConnectionState.done
        ? MainApp(service: snapshot.data)
        : const BrandSplash(),
  );
}

class MainApp extends StatefulWidget {
  const MainApp({
    this.service,
    this.repositoryBuilder,
    this.demoBuilder,
    super.key,
  });
  final Widget Function(ValueChanged<AccessibilityPreferences>)? demoBuilder;
  final AuthService? service;
  final SeekerRepository Function(AuthService, String)? repositoryBuilder;
  @override
  State<MainApp> createState() => _MainAppState();
}

class _MainAppState extends State<MainApp> with WidgetsBindingObserver {
  AccessibilityPreferences _preferences = const AccessibilityPreferences();
  StreamSubscription<AuthState>? _subscription;
  String? _user;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _user = widget.service?.userId;
    _subscription = widget.service?.authChanges.listen((_) {
      final next = widget.service?.userId;
      if (next != _user && mounted) {
        setState(() {
          _user = next;
          _preferences = const AccessibilityPreferences();
        });
      }
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAccessibilityFeatures() {
    if (mounted) {
      setState(() {});
    }
  }

  bool get _reduceMotion =>
      _preferences.reduceMotion ||
      WidgetsBinding
          .instance
          .platformDispatcher
          .accessibilityFeatures
          .disableAnimations;
  void _apply(AccessibilityPreferences value) {
    if (mounted &&
        (_preferences.textScale != value.textScale ||
            _preferences.highContrast != value.highContrast ||
            _preferences.reduceMotion != value.reduceMotion)) {
      setState(() => _preferences = value);
    }
  }

  ThemeData _theme(Brightness brightness, {bool contrast = false}) =>
      AppTheme.forBrightness(
        brightness,
        highContrast: contrast,
        reduceMotion: _reduceMotion,
      );
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'EnableWork+',
    debugShowCheckedModeBanner: false,
    theme: _theme(Brightness.light, contrast: _preferences.highContrast),
    darkTheme: _theme(Brightness.dark, contrast: _preferences.highContrast),
    highContrastTheme: _theme(Brightness.light, contrast: true),
    highContrastDarkTheme: _theme(Brightness.dark, contrast: true),
    themeAnimationDuration: _reduceMotion
        ? Duration.zero
        : const Duration(milliseconds: 200),
    builder: (context, child) {
      final system = MediaQuery.of(context);
      return MediaQuery(
        data: system.copyWith(
          textScaler: PreferenceTextScaler(
            system.textScaler,
            _preferences.textScale,
          ),
          disableAnimations:
              system.disableAnimations || _preferences.reduceMotion,
          accessibleNavigation:
              system.accessibleNavigation || _preferences.reduceMotion,
        ),
        child: child!,
      );
    },
    home: Scaffold(
      appBar: widget.demoBuilder == null
          ? null
          : AppBar(title: const Text('EnableWork+ · Sample data')),
      body: SafeArea(
        child:
            widget.demoBuilder?.call(_apply) ??
            (widget.service == null
                ? const Center(
                    child: SingleChildScrollView(
                      padding: EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          BrandIdentity(),
                          SizedBox(height: 24),
                          Text(
                            'Unable to connect to EnableWork+. Start the app with its approved hosted configuration, then try again.',
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  )
                : AuthScreen(
                    service: widget.service!,
                    authenticatedBuilder: (context, invalidate) {
                      final id = widget.service!.userId;
                      if (id == null) return const SizedBox.shrink();
                      return SeekerHome(
                        key: ValueKey(id),
                        repository:
                            widget.repositoryBuilder?.call(
                              widget.service!,
                              id,
                            ) ??
                            SupabaseSeekerRepository(widget.service!, id),
                        onPreferences: _apply,
                        onAccessLost: () {
                          _apply(const AccessibilityPreferences());
                          invalidate();
                        },
                        onSignOut: widget.service!.signOut,
                      );
                    },
                  )),
      ),
    ),
  );
}
