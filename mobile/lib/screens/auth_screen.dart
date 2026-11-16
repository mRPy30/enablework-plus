import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/auth_service.dart';
import '../models/account_profile.dart';
import '../widgets/workspace_widgets.dart';
import '../widgets/brand_identity.dart';

/// Auth gate for the protected job-seeker workspace.
class AuthScreen extends StatefulWidget {
  const AuthScreen({
    required this.service,
    this.authenticatedBuilder,
    super.key,
  });
  final AuthService service;
  final Widget Function(BuildContext, VoidCallback)? authenticatedBuilder;
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
  bool _showPassword = false;

  @override
  void initState() {
    super.initState();
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
      onError: (Object _) {
        if (mounted) {
          setState(() {
            _access = Future.value(false);
            _message = 'Session unavailable. Please sign in again.';
          });
        }
      },
    );
  }

  Future<bool> _checkAccess() async {
    if (!widget.service.hasSession) return false;
    try {
      final account = await widget.service.requireAccess();
      return account.role == AppRole.jobSeeker;
    } catch (_) {
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
    } catch (_) {
      if (mounted) {
        setState(() {
          _message = 'Unable to complete the request. Check your details and account access.';
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
        return const Center(
          child: BusyIndicator(label: 'Checking account access'),
        );
      }
      final authenticated = snapshot.data ?? false;
      if (authenticated &&
          !_recovering &&
          widget.authenticatedBuilder != null) {
        return widget.authenticatedBuilder!(context, () {
          if (mounted) {
            setState(() {
              _access = Future.value(false);
              _message = 'Your account access changed. Please sign in again.';
            });
          }
        });
      }
      return Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const BrandIdentity(),
                const SizedBox(height: 12),
                Text(
                  _recovering ? 'Reset your password' : 'Welcome back',
                  style: Theme.of(context).textTheme.headlineMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  _recovering
                      ? 'Create a new password to keep your account secure.'
                      : 'Find work that works for you, with an experience shaped around your access needs.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 22),
                if (authenticated && !_recovering) ...[
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'PWD Job Seeker',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Authentication verified. Your protected workspace is ready.',
                          ),
                        ],
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
                              'PWD Job Seeker',
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
                          if (!_recovering)
                            TextField(
                              controller: _name,
                              decoration: const InputDecoration(
                                labelText: 'Name (registration only)',
                                prefixIcon: Icon(Icons.person_outline),
                              ),
                              maxLength: 120,
                            ),
                          if (!_recovering) const SizedBox(height: 4),
                          TextField(
                            controller: _password,
                            obscureText: !_showPassword,
                            enableSuggestions: false,
                            autocorrect: false,
                            decoration: InputDecoration(
                              labelText: _recovering
                                  ? 'New password (at least 12 characters)'
                                  : 'Password',
                              prefixIcon: const Icon(Icons.lock_outline),
                              suffixIcon: IconButton(
                                tooltip: _showPassword
                                    ? 'Hide password'
                                    : 'Show password',
                                constraints: const BoxConstraints(
                                  minWidth: 48,
                                  minHeight: 48,
                                ),
                                onPressed: () => setState(() {
                                  _showPassword = !_showPassword;
                                }),
                                icon: Icon(
                                  _showPassword
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  if (_recovering)
                    FilledButton(
                      onPressed: _busy
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
                              () => widget.service.signUp(
                                _email.text,
                                _password.text,
                                _name.text,
                              ),
                              success: 'Check the local email inbox to confirm registration.',
                            ),
                      child: const Text('Register as a job seeker'),
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
