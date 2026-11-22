import 'package:flutter/material.dart';

class AiAssistantSheet extends StatelessWidget {
  const AiAssistantSheet({
    required this.onScanResume,
    required this.onFindMatch,
    required this.onBuildResume,
    required this.onAccessibility,
    required this.onSignLanguage,
    required this.matchingAvailable,
    super.key,
  });

  final VoidCallback onScanResume;
  final VoidCallback onFindMatch;
  final VoidCallback onBuildResume;
  final VoidCallback onAccessibility;
  final VoidCallback onSignLanguage;
  final bool matchingAvailable;

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('EnableWork+ Assistant', style: Theme.of(context).textTheme.titleLarge),
          const Text('Quick access to your career tools. Results support your decisions; they do not make hiring decisions.'),
          _ActionTile(icon: Icons.document_scanner_outlined, title: 'Scan my resume', subtitle: 'Review skills, structure, and accessibility notes', onTap: onScanResume),
          _ActionTile(icon: Icons.work_outline, title: 'Find my job fit', subtitle: matchingAvailable ? 'Compare a job with your profile and resume' : 'Available after the matching service is connected', onTap: onFindMatch, enabled: matchingAvailable),
          _ActionTile(icon: Icons.edit_note, title: 'Build an accessible resume', subtitle: 'Create a structured resume with accessibility in mind', onTap: onBuildResume),
          _ActionTile(icon: Icons.accessibility_new, title: 'Update accessibility preferences', subtitle: 'Adjust the experience to fit your access needs', onTap: onAccessibility),
          _ActionTile(icon: Icons.sign_language_outlined, title: 'Sign language support', subtitle: 'Use communication phrases and check translation status', onTap: onSignLanguage),
        ],
      ),
    ),
  );
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({required this.icon, required this.title, required this.subtitle, required this.onTap, this.enabled = true});
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: const EdgeInsets.symmetric(vertical: 4),
    enabled: enabled,
    leading: Icon(icon),
    title: Text(title),
    subtitle: Text(subtitle),
    trailing: const Icon(Icons.chevron_right),
    onTap: enabled ? onTap : null,
  );
}
