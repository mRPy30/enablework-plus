import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/auth_service.dart';
import '../services/auth_callback.dart';
import '../widgets/admin_widgets.dart';
import '../theme/admin_theme.dart';

/// Authentication foundation only; job, profile and administrative feature screens are deferred.
class AuthScreen extends StatefulWidget {
  const AuthScreen({
    required this.service,
    this.authenticatedBuilder,
    this.passwordSetup = false,
    this.initialMessage,
    super.key,
  });
  final AuthService service;
  final bool passwordSetup;
  final String? initialMessage;
  final Widget Function(BuildContext, Future<void> Function())?
  authenticatedBuilder;
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _name = TextEditingController();
  StreamSubscription<AuthState>? _subscription;
  Future<bool>? _access;
  String? _message;
  bool _busy = false;
  bool _recovering = false;

  @override
  void initState() {
    super.initState();
    _recovering = widget.passwordSetup && widget.initialMessage == null;
    _message = widget.initialMessage;
    _access = _checkAccess();
    _subscription = widget.service.authChanges.listen(
      (event) {
        if (!mounted) return;
        setState(() {
          if (event.event == AuthChangeEvent.passwordRecovery) {
            _recovering = true;
          }
          if (event.event == AuthChangeEvent.signedOut) _recovering = false;
          _access = _checkAccess();
        });
      },
      onError: (Object error) {
        if (mounted) {
          setState(() {
            _access = Future.value(false);
            _recovering = false;
            _message = authFailureMessage(error);
          });
        }
      },
    );
  }

  Future<bool> _checkAccess() async {
    if (!widget.service.hasSession) return false;
    try {
      await widget.service.requireAccess();
      return true;
    } catch (error) {
      _recovering = false;
      _message = authFailureMessage(error);
      return false;
    }
  }

  Future<void> _perform(
    Future<void> Function() operation, {
    String? success,
  }) async {
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await operation();
      if (mounted) {
        setState(() {
          _message = success;
          _access = _checkAccess();
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _message = authFailureMessage(error);
        });
      }
    } finally {
      if (mounted) {
        _password.clear();
        setState(() {
          _busy = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _email.dispose();
    _password.dispose();
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<bool>(
    future: _access,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const Center(child: CircularProgressIndicator());
      }
      final authenticated = snapshot.data ?? false;
      if (authenticated &&
          !_recovering &&
          widget.authenticatedBuilder != null) {
        return widget.authenticatedBuilder!(context, widget.service.signOut);
      }
      return Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const AdminBrand(),
                const SizedBox(height: 16),
                Text(
                  _recovering ? 'Set administrator password' : 'Welcome back',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineMedium
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                Text(
                  _recovering
                      ? 'Create a new password for your secure console access.'
                      : 'Sign in with a provisioned System Administrator account.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge
                      ?.copyWith(color: AdminColors.muted),
                ),
                const SizedBox(height: 20),
                if (authenticated && !_recovering) ...[
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Text(
                        'Authentication verified. The protected administrator console is ready.',
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: _busy
                        ? null
                        : () => _perform(widget.service.signOut),
                    child: const Text('Sign out'),
                  ),
                ] else ...[
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (!_recovering)
                            Text(
                              'System Administrator',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                          if (!_recovering) const SizedBox(height: 16),
                          if (!_recovering)
                            TextField(
                              controller: _email,
                              keyboardType: TextInputType.emailAddress,
                              autocorrect: false,
                              decoration: const InputDecoration(
                                labelText: 'Email',
                                prefixIcon: Icon(Icons.mail_outline),
                              ),
                            ),
                          if (!_recovering) const SizedBox(height: 12),
                          TextField(
                            controller: _password,
                            obscureText: true,
                            enableSuggestions: false,
                            autocorrect: false,
                            decoration: InputDecoration(
                              labelText: _recovering
                                  ? 'New password (at least 12 characters)'
                                  : 'Password',
                              prefixIcon: const Icon(Icons.lock_outline),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  if (_recovering)
                    FilledButton(
                      onPressed: _busy || !authenticated
                          ? null
                          : () => _perform(() async {
                              await widget.service.updatePassword(
                                _password.text,
                              );
                              if (mounted) {
                                setState(() {
                                  _recovering = false;
                                });
                              }
                            }, success: 'Password updated.'),
                      child: const Text('Update password'),
                    )
                  else ...[
                    FilledButton(
                      onPressed: _busy
                          ? null
                          : () => _perform(
                              () => widget.service.signIn(
                                _email.text,
                                _password.text,
                              ),
                            ),
                      child: const Text('Sign in'),
                    ),

                    TextButton(
                      onPressed: _busy
                          ? null
                          : () => _perform(
                              () => widget.service.requestPasswordReset(
                                _email.text,
                              ),
                              success: 'If the account exists, recovery instructions have been sent.',
                            ),
                      child: const Text('Forgot password'),
                    ),
                  ],
                  if (widget.service.hasSession)
                    TextButton(
                      onPressed: _busy
                          ? null
                          : () => _perform(widget.service.signOut),
                      child: const Text('Clear session'),
                    ),
                ],
                if (_message != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Text(_message!, semanticsLabel: _message),
                  ),
              ],
            ),
          ),
        ),
      );
    },
  );
}
