import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'screens/sign_library.dart';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'models/seeker_workspace.dart';
import 'services/app_config.dart';
import 'services/auth_service.dart';
import 'services/secure_auth_storage.dart';
import 'services/seeker_repository.dart';
import 'screens/auth_screen.dart';
import 'screens/start_support_screen.dart';
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
  late Future<AuthService?> _service = _initialize();

  late final Stream<bool> _network = const EventChannel(
    'enablework_plus/connectivity',
  ).receiveBroadcastStream().cast<bool>().distinct();
  Set<StartSupport>? _start;
  Future<AuthService?> _initialize() async {
    try {
      _start = await StartPreferences.load();
    } catch (_) {
      // Users can still choose supports when secure storage is unavailable.
    }
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
        ? MainApp(
            service: snapshot.data,
            deviceSupport: true,
            initialSupport: _start,
            connectivity:
                !kIsWeb && defaultTargetPlatform == TargetPlatform.android
                ? _network
                : null,
            retryStartup: () => setState(() => _service = _initialize()),
          )
        : const BrandSplash(),
  );
}

class MainApp extends StatefulWidget {
  const MainApp({
    this.service,
    this.deviceSupport = false,
    this.initialSupport,
    this.connectivity,
    this.retryStartup,
    this.repositoryBuilder,
    this.demoBuilder,
    super.key,
  });
  final Widget Function(ValueChanged<AccessibilityPreferences>)? demoBuilder;
  final Stream<bool>? connectivity;
  final VoidCallback? retryStartup;
  final AuthService? service;
  final bool deviceSupport;
  final Set<StartSupport>? initialSupport;
  final SeekerRepository Function(AuthService, String)? repositoryBuilder;
  @override
  State<MainApp> createState() => _MainAppState();
}

class _MainAppState extends State<MainApp> with WidgetsBindingObserver {
  AccessibilityPreferences _preferences = const AccessibilityPreferences();
  late Set<StartSupport> _start = {...?widget.initialSupport};
  late bool _choosing = widget.deviceSupport && widget.initialSupport == null;
  final _navigator = GlobalKey<NavigatorState>();
  final _messenger = GlobalKey<ScaffoldMessengerState>();
  Future<void> _finishStart() async {
    try {
      await StartPreferences.save(_start);
    } catch (_) {
      _messenger.currentState?.showSnackBar(
        const SnackBar(
          content: Text(
            'Your choices apply for this session. Device storage is unavailable.',
          ),
        ),
      );
    }
    if (mounted) setState(() => _choosing = false);
  }

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
      _start.contains(StartSupport.calm) ||
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

  bool _libraryOpen = false;
  Future<void> _openOfflineLibrary() async {
    if (_libraryOpen) return;
    _libraryOpen = true;
    try {
      await _navigator.currentState?.push(
        MaterialPageRoute<void>(builder: (_) => const SignLibrary()),
      );
    } finally {
      _libraryOpen = false;
    }
  }

  ThemeData _theme(Brightness brightness, {bool contrast = false}) =>
      AppTheme.forBrightness(
        brightness,
        highContrast: contrast || _start.contains(StartSupport.reading),
        largerControls: _start.contains(StartSupport.touch),
        reduceMotion: _reduceMotion,
      );
  @override
  Widget build(BuildContext context) => MaterialApp(
    scaffoldMessengerKey: _messenger,
    navigatorKey: _navigator,
    title: 'EnableWork+',
    debugShowCheckedModeBanner: false,
    scrollBehavior: const MaterialScrollBehavior().copyWith(
      dragDevices: {PointerDeviceKind.touch, PointerDeviceKind.mouse},
    ),
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
            _start.contains(StartSupport.reading)
                ? math.max(1.35, _preferences.textScale)
                : _preferences.textScale,
          ),
          disableAnimations: system.disableAnimations || _reduceMotion,
          accessibleNavigation: system.accessibleNavigation || _reduceMotion,
        ),
        child: StreamBuilder<bool>(
          stream: widget.connectivity,
          builder: (context, snapshot) => Column(
            children: [
              if (snapshot.data == false)
                Material(
                  color: Theme.of(context).colorScheme.secondaryContainer,
                  child: SafeArea(
                    bottom: false,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Row(
                        children: [
                          const Icon(Icons.cloud_off_outlined),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Semantics(
                              liveRegion: true,
                              child: const Text(
                                'You are offline. Jobs and AI need internet.',
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: _openOfflineLibrary,
                            child: const Text('Offline FSL'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              Expanded(child: child!),
            ],
          ),
        ),
      );
    },
    home: Stack(
      fit: StackFit.expand,
      children: [
        Offstage(
          offstage: _choosing,
          child: ExcludeFocus(
            excluding: _choosing,
            child: Scaffold(
              appBar: widget.demoBuilder == null
                  ? null
                  : AppBar(title: const Text('EnableWork+ · Sample data')),
              body: SafeArea(
                child: Column(
                  children: [
                    if (widget.deviceSupport && _user == null)
                      Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: TextButton.icon(
                          onPressed: () => setState(() => _choosing = true),
                          icon: const Icon(Icons.accessibility_new),
                          label: const Text('Display and controls'),
                        ),
                      ),
                    Expanded(
                      child:
                          widget.demoBuilder?.call(_apply) ??
                          (widget.service == null
                              ? Center(
                                  child: SingleChildScrollView(
                                    padding: EdgeInsets.all(24),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const BrandIdentity(),
                                        const SizedBox(height: 24),
                                        const Text(
                                          'Unable to connect to EnableWork+. Start the app with its approved hosted configuration, then try again.',
                                          textAlign: TextAlign.center,
                                        ),
                                        if (widget.retryStartup != null)
                                          TextButton(
                                            onPressed: widget.retryStartup,
                                            child: const Text('Try again'),
                                          ),
                                      ],
                                    ),
                                  ),
                                )
                              : AuthScreen(
                                  service: widget.service!,
                                  onDisplay:
                                      widget.deviceSupport && _user != null
                                      ? () => setState(() => _choosing = true)
                                      : null,
                                  authenticatedBuilder: (context, invalidate) {
                                    final id = widget.service!.userId;
                                    if (id == null) {
                                      return const SizedBox.shrink();
                                    }
                                    return SeekerHome(
                                      key: ValueKey(id),
                                      repository:
                                          widget.repositoryBuilder?.call(
                                            widget.service!,
                                            id,
                                          ) ??
                                          SupabaseSeekerRepository(
                                            widget.service!,
                                            id,
                                          ),
                                      onDisplay: () =>
                                          setState(() => _choosing = true),
                                      onPreferences: _apply,
                                      onAccessLost: () {
                                        _apply(
                                          const AccessibilityPreferences(),
                                        );
                                        invalidate();
                                      },
                                      onSignOut: widget.service!.signOut,
                                    );
                                  },
                                )),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (_choosing)
          StartSupportScreen(
            choices: _start,
            change: (v) => setState(() => _start = v),
            finish: _finishStart,
          ),
      ],
    ),
  );
}
