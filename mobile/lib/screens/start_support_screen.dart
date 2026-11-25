import 'fsl_section_guide.dart';
import '../widgets/welcome_guide.dart';
import 'accessibility_screen.dart';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

enum StartSupport {
  reading('Larger text and stronger contrast'),
  touch('Larger buttons'),
  calm('Reduce animations');

  const StartSupport(this.label);
  final String label;
}

class StartPreferences {
  static const _key = 'enablework.device.start_support.v1';
  static const _storage = FlutterSecureStorage();

  static Future<Set<StartSupport>?> load() async {
    final raw = await _storage.read(key: _key);
    if (raw == null) return null;
    return StartSupport.values
        .where((s) => raw.split(',').contains(s.name))
        .toSet();
  }

  static Future<void> save(Set<StartSupport> choices) =>
      _storage.write(key: _key, value: choices.map((s) => s.name).join(','));
}

class StartSupportScreen extends StatefulWidget {
  const StartSupportScreen({
    required this.choices,
    required this.change,
    required this.finish,
    super.key,
  });
  final Set<StartSupport> choices;
  final ValueChanged<Set<StartSupport>> change;
  final Future<void> Function() finish;
  @override
  State<StartSupportScreen> createState() => _StartSupportScreenState();
}

class _StartSupportScreenState extends State<StartSupportScreen> {
  bool saving = false;
  static const speech = MethodChannel('enablework_plus/tts');
  Future<void> _read() async {
    try {
      await speech.invokeMethod<void>('speak', {
        'text': 'Welcome to EnableWork Plus. Choose larger text and stronger contrast, larger buttons, or reduced animations. Select Continue when ready.',
      });
    } on PlatformException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Read aloud is unavailable.')),
        );
      }
    } on MissingPluginException {
      return;
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const WelcomeGuide(),
        const FslSectionGuide(GuideSection.welcome),
          const SizedBox(height: 12),
          const Text(
            'How would you like to use this app? Choose any supports for this device. You can change them later.',
          ),
          if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android)
            TextButton.icon(
              onPressed: _read,
              icon: const Icon(Icons.volume_up),
              label: const Text('Read these options aloud'),
            ),
          TextButton.icon(
            icon: const Icon(Icons.sign_language_outlined),
            label: const Text('Filipino Sign Language resources'),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => Scaffold(
                  appBar: AppBar(title: const Text('Filipino Sign Language')),
                  body: const SafeArea(child: SignLanguageSupportScreen()),
                ),
              ),
            ),
          ),
          for (final support in StartSupport.values)
            SwitchListTile(
              title: Text(support.label),
              value: widget.choices.contains(support),
              onChanged: saving
                  ? null
                  : (on) {
                      final choices = {...widget.choices};
                      if (on) {
                        choices.add(support);
                      } else {
                        choices.remove(support);
                      }
                      widget.change(choices);
                    },
            ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: saving
                ? null
                : () async {
                    setState(() => saving = true);
                    await widget.finish();
                    if (mounted) setState(() => saving = false);
                  },
            child: const Text('Continue'),
          ),
        ],
      ),
    ),
  );
}
