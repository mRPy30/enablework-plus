import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';

/// The guide signs the recorded FSL greeting. The account name is presented
/// separately so a written name is never passed off as a person's name sign.
class WelcomeGuide extends StatefulWidget {
  const WelcomeGuide({this.name = '', super.key});
  final String name;
  @override
  State<WelcomeGuide> createState() => _WelcomeGuideState();
}

class _WelcomeGuideState extends State<WelcomeGuide> {
  static const motion = AssetImage('assets/guide/hello.webp');
  static const still = AssetImage('assets/guide/hello-still.png');
  static const speech = MethodChannel('enablework_plus/tts');
  String get greeting =>
      widget.name.isEmpty ? 'Hello!' : 'Hello, ${widget.name}!';
  Future<void> play() async {
    final file = await rootBundle.load('assets/guide/hello.webp');
    if (!mounted) return;
    // A fresh provider starts at the first frame even when Home has already played.
    final bytes = Uint8List.fromList(
      file.buffer.asUint8List(file.offsetInBytes, file.lengthInBytes),
    );
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hello in Filipino Sign Language'),
        content: Image.memory(
          bytes,
          fit: BoxFit.contain,
          semanticLabel: 'Guide signing Hello',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> read() async {
    try {
      await speech.invokeMethod<void>('speak', {
        'text': '$greeting Welcome to EnableWork Plus.',
      });
    } on PlatformException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Read aloud is unavailable on this device.'),
          ),
        );
      }
    } on MissingPluginException {
      return;
    }
  }

  @override
  Widget build(BuildContext context) {
    final animate = !MediaQuery.disableAnimationsOf(context);
    final theme = Theme.of(context);
    final title = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          header: true,
          child: Text(
            greeting,
            style: theme.textTheme.headlineMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const Text(
          'Welcome to EnableWork+',
          style: TextStyle(color: Colors.white),
        ),
      ],
    );
    final signer = ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: Image(
          image: animate ? motion : still,
          fit: BoxFit.contain,
          semanticLabel:
              'EnableWork+ guide, Filipino Sign Language greeting: Hello.',
        ),
      ),
    );
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.royalBlue,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            LayoutBuilder(
              builder: (_, size) {
                if (size.maxWidth < 260 ||
                    MediaQuery.textScalerOf(context).scale(16) > 22) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      title,
                      const SizedBox(height: 8),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 240),
                        child: signer,
                      ),
                    ],
                  );
                }
                return Row(
                  children: [
                    Expanded(child: title),
                    const SizedBox(width: 8),
                    Expanded(child: signer),
                  ],
                );
              },
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              children: [
                TextButton.icon(
                  style: TextButton.styleFrom(foregroundColor: Colors.white),
                  onPressed: play,
                  icon: const Icon(
                    Icons.sign_language,
                    color: AppColors.sunYellow,
                  ),
                  label: const Text('Play FSL hello'),
                ),
                if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android)
                  IconButton(
                    onPressed: read,
                    tooltip: 'Read greeting aloud',
                    icon: const Icon(Icons.volume_up, color: Colors.white),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
