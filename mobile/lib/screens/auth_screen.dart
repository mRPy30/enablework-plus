import 'fsl_section_guide.dart';
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
    this.onDisplay,
    super.key,
  });
  final AuthService service;
  final VoidCallback? onDisplay;
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
  bool _registering = false;
  bool _showPassword = false;

  String _authMessage(Object error) {
    if (error is AuthException) {
      final message = error.message.toLowerCase();
      if (message.contains('invalid login credentials')) {
        return 'Incorrect email or password. Check both fields and try again.';
      }
      if (message.contains('email not confirmed')) {
        return 'Confirm your email before signing in. Check your Inbox and Spam folder.';
      }
      if (message.contains('user already registered')) {
        return 'This email is already registered. Use Sign in instead.';
      }
      if (message.contains('password')) {
        return 'Password must meet the account requirements.';
      }
      return 'Authentication error: ${error.message}';
    }
    if (error is StateError) return error.message.toString();
    if (error is PostgrestException) {
      return 'Account access could not be verified. Please try again.';
    }
    if (error is FormatException) return error.message;
    if (error is TimeoutException) {
      return 'EnableWork+ could not reach the account service. Check your connection and try again.';
    }
    return 'Something went wrong. Check your connection and try again.';
  }

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
      final account = await widget.service.requireAccess().timeout(
        const Duration(seconds: 12),
        onTimeout: () => throw TimeoutException('Account check timed out'),
      );
      return account.role == AppRole.jobSeeker;
    } catch (error) {
      if (mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          setState(() {
            _message = error is TimeoutException
                ? 'Account check timed out. Check your connection, then sign in again.'
                : 'Your saved session could not be verified. Please sign in again.';
          });
        });
      }
      return false;
    }
  }

  Future<void> _perform(
    Future<void> Function() operation, {
    String? success,
  }) async {
    var completed = false;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await operation();
      completed = true;
      if (mounted) {
        setState(() {
          _message = success;
          _access = _checkAccess();
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _message = _authMessage(error);
        });
      }
    } finally {
      if (mounted) {
        if (completed) _password.clear();
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
        const FslSectionGuide(GuideSection.account),
                const SizedBox(height: 12),
                Text(
                  _recovering
                      ? 'Reset your password'
                      : _registering
                      ? 'Create your account'
                      : 'Welcome back',
                  style: Theme.of(context).textTheme.headlineMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  _recovering
                      ? 'Create a new password to keep your account secure.'
                      : _registering
                      ? 'Register as a PWD Job Seeker. We will send a confirmation link to your email.'
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
                              _registering
                                  ? 'Job seeker registration'
                                  : 'PWD Job Seeker',
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
                          if (_registering) const SizedBox(height: 12),
                          if (_registering)
                            TextField(
                              controller: _name,
                              decoration: const InputDecoration(
                                labelText: 'Full name',
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
                                  : _registering
                                  ? 'Create password (at least 12 characters)'
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
                  else if (_registering) ...[
                    FilledButton(
                      onPressed: _busy
                          ? null
                          : () => _perform(
                              () async {
                                if (_email.text.trim().isEmpty ||
                                    _name.text.trim().isEmpty ||
                                    _password.text.length < 12) {
                                  throw const FormatException(
                                    'Enter your email and full name, then use a password with at least 12 characters.',
                                  );
                                }
                                await widget.service.signUp(
                                  _email.text,
                                  _password.text,
                                  _name.text,
                                );
                              },
                              success: 'Registration submitted. Check your email inbox and Spam folder for the confirmation link.',
                            ),
                      child: const Text('Create job seeker account'),
                    ),
                    TextButton(
                      onPressed: _busy
                          ? null
                          : () => setState(() {
                              _registering = false;
                              _message = null;
                              _name.clear();
                              _password.clear();
                            }),
                      child: const Text('Back to sign in'),
                    ),
                  ] else ...[
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
                          : () => setState(() {
                              _registering = true;
                              _message = null;
                              _password.clear();
                            }),
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
                  Container(
                    margin: const EdgeInsets.only(top: 16),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color:
                          _message!.startsWith('Authentication') ||
                              _message!.startsWith('Incorrect') ||
                              _message!.startsWith('Something') ||
                              _message!.startsWith('EnableWork+')
                          ? Theme.of(context).colorScheme.errorContainer
                          : Theme.of(context).colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Semantics(
                      liveRegion: true,
                      child: Text(
                        _message!,
                        semanticsLabel: _message,
                        style: TextStyle(
                          color:
                              _message!.startsWith('Authentication') ||
                                  _message!.startsWith('Incorrect') ||
                                  _message!.startsWith('Something') ||
                                  _message!.startsWith('EnableWork+')
                              ? Theme.of(context).colorScheme.onErrorContainer
                              : Theme.of(context)
                                    .colorScheme
                                    .onPrimaryContainer,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    },
  );
}
