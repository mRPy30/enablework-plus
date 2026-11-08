import 'package:flutter/material.dart';

import '../models/seeker_workspace.dart';
import '../services/seeker_repository.dart';
import '../state/seeker_controller.dart';
import '../widgets/workspace_widgets.dart';
import 'dashboard_screen.dart';
import 'profile_screen.dart';
import 'resumes_screen.dart';
import 'accessibility_screen.dart';

class SeekerHome extends StatefulWidget {
  const SeekerHome({
    required this.repository,
    required this.onPreferences,
    required this.onAccessLost,
    required this.onSignOut,
    this.picker,
    super.key,
  });
  final SeekerRepository repository;
  final void Function(AccessibilityPreferences) onPreferences;
  final VoidCallback onAccessLost;
  final Future<void> Function() onSignOut;
  final PdfPicker? picker;
  @override
  State<SeekerHome> createState() => _SeekerHomeState();
}

class _SeekerHomeState extends State<SeekerHome> with WidgetsBindingObserver {
  late final SeekerController _controller;
  late final PdfPicker _picker;
  int _tab = 0;
  String? _sessionError;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _picker = widget.picker ?? DevicePdfPicker();
    _controller = SeekerController(
      widget.repository,
      onPreferences: widget.onPreferences,
      onAccessLost: widget.onAccessLost,
    )..load();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !_controller.busy) {
      _controller.load();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    super.dispose();
  }

  Future<void> _signOut() async {
    try {
      await widget.onSignOut();
    } catch (_) {
      if (mounted) {
        setState(() => _sessionError = 'Unable to sign out. Please try again.');
      }
    }
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _controller,
    builder: (context, _) => Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              IconButton(
                tooltip: 'Refresh your information',
                onPressed: _controller.busy || _controller.loading
                    ? null
                    : _controller.load,
                icon: const Icon(Icons.refresh),
              ),
              TextButton.icon(
                onPressed: _controller.busy ? null : _signOut,
                icon: const Icon(Icons.logout),
                label: const Text('Sign out'),
              ),
            ],
          ),
        ),
        if (_controller.error != null)
          WorkspaceError(
            message: _controller.error!,
            onDismiss: _controller.clearError,
          ),
        if (_sessionError != null)
          WorkspaceError(
            message: _sessionError!,
            onDismiss: () => setState(() => _sessionError = null),
          ),
        if (_controller.busy) BusyIndicator(label: _controller.progress),
        Expanded(
          child: _controller.data == null
              ? _controller.loading
                    ? const Center(
                        child: BusyIndicator(label: 'Loading your workspace'),
                      )
                    : Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text('Your workspace could not be loaded.'),
                              const SizedBox(height: 12),
                              FilledButton(
                                onPressed: _controller.load,
                                child: const Text('Try again'),
                              ),
                            ],
                          ),
                        ),
                      )
              : IndexedStack(
                  index: _tab,
                  children: [
                    DashboardScreen(
                      data: _controller.data!,
                      openTab: (value) => setState(() => _tab = value),
                    ),
                    ProfileScreen(controller: _controller),
                    ResumesScreen(controller: _controller, picker: _picker),
                    AccessibilityScreen(controller: _controller),
                  ],
                ),
        ),
        NavigationBar(
          height:
              80 +
              (MediaQuery.textScalerOf(context).scale(12) - 12).clamp(0, 60) *
                  2,
          selectedIndex: _tab,
          animationDuration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : const Duration(milliseconds: 200),
          labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
          onDestinationSelected: _controller.data == null
              ? null
              : (value) => setState(() => _tab = value),
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home),
              label: 'Home',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person),
              label: 'Profile',
            ),
            NavigationDestination(
              icon: Icon(Icons.description_outlined),
              selectedIcon: Icon(Icons.description),
              label: 'Resumes',
            ),
            NavigationDestination(
              icon: Icon(Icons.accessibility_new),
              label: 'Settings',
              tooltip: 'Accessibility preferences',
            ),
          ],
        ),
      ],
    ),
  );
}
