import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

bool get androidVoice =>
    !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

class VoiceScope extends InheritedWidget {
  const VoiceScope({required this.enabled, required super.child, super.key});
  final bool enabled;
  static bool of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<VoiceScope>()?.enabled ??
      false;
  @override
  bool updateShouldNotify(VoiceScope oldWidget) => oldWidget.enabled != enabled;
}

const speechOutput = MethodChannel('enablework_plus/tts');
Future<void> stopVoice() async {
  if (!androidVoice) return;
  try {
    await speechOutput.invokeMethod<void>('stop');
  } on PlatformException {
    return;
  } on MissingPluginException {
    return;
  }
}

Future<void> speakVoice(
  BuildContext context,
  String text, {
  bool automatic = false,
}) async {
  if (!androidVoice) return;
  try {
    await speechOutput.invokeMethod<void>('speak', {
      'text': text,
      'automatic': automatic,
    });
  } on PlatformException {
    if (!automatic && context.mounted) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(
          content: Text('Speech playback is unavailable on this device.'),
        ),
      );
    }
  } on MissingPluginException {
    return;
  }
}

class VoiceActions extends StatelessWidget {
  const VoiceActions(this.label, this.message, {super.key});
  final String label, message;
  @override
  Widget build(BuildContext context) => Wrap(
    children: [
      TextButton.icon(
        onPressed: () => speakVoice(context, message),
        icon: const Icon(Icons.volume_up),
        label: Text(label),
      ),
      IconButton(
        onPressed: stopVoice,
        tooltip: 'Stop speech',
        icon: const Icon(Icons.stop_circle_outlined),
      ),
    ],
  );
}

class TabVoiceGuide extends StatefulWidget {
  const TabVoiceGuide(this.tab, {super.key});
  final int tab;
  @override
  State<TabVoiceGuide> createState() => _TabVoiceGuideState();
}

class _TabVoiceGuideState extends State<TabVoiceGuide> {
  static const hints = [
    'Home. Search for jobs or open a quick action.',
    'Jobs. Type a job title or use the microphone, then select View job.',
    'Applications. Open an application to hear its status using your screen reader.',
    'Profile. Edit your skills and experience, then select Save profile.',
    'Settings. Choose accessibility features and confirm your changes.',
  ];
  void announce() => WidgetsBinding.instance.addPostFrameCallback((_) {
    if (mounted && ModalRoute.of(context)?.isCurrent == true) {
      speakVoice(context, hints[widget.tab], automatic: true);
    }
  });
  @override
  void initState() {
    super.initState();
    announce();
  }

  @override
  void didUpdateWidget(TabVoiceGuide oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.tab != oldWidget.tab) announce();
  }

  @override
  void dispose() {
    stopVoice();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      VoiceActions('Hear navigation help', hints[widget.tab]);
}
