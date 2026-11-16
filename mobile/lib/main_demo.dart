import 'package:flutter/material.dart';

import 'demo/demo_workspace.dart';
import 'main.dart' show MainApp;
import 'models/seeker_workspace.dart';
import 'screens/seeker_home.dart';
import 'widgets/brand_identity.dart';

/// Separate entry point: the production bootstrap and Auth are never invoked.
void main() => runApp(const ClientDemo());

class ClientDemo extends StatefulWidget {
  const ClientDemo({super.key});
  @override
  State<ClientDemo> createState() => _ClientDemoState();
}

class _ClientDemoState extends State<ClientDemo> {
  DemoWorkspace? _session;
  @override
  Widget build(BuildContext context) => MainApp(
    demoBuilder: (apply) {
      final repo = _session;
      void exit() {
        apply(const AccessibilityPreferences());
        setState(() => _session = null);
      }

      if (repo != null) {
        return SeekerHome(
          key: ObjectKey(repo),
          repository: repo,
          preview: repo,
          addSampleResume: repo.addSample,
          onPreferences: apply,
          onAccessLost: exit,
          onSignOut: () async => exit(),
        );
      }
      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const BrandIdentity(),
              const SizedBox(height: 24),
              const Text(
                'Explore sample jobs and practice applying with a sample resume. Your changes last only for this session.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () => setState(() => _session = DemoWorkspace()),
                icon: const Icon(Icons.arrow_forward),
                label: const Text('Get started'),
              ),
            ],
          ),
        ),
      );
    },
  );
}
