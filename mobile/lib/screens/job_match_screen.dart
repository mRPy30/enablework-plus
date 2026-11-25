import 'fsl_section_guide.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/job_match_repository.dart';
import '../widgets/workspace_widgets.dart';

class JobMatchScreen extends StatefulWidget {
  const JobMatchScreen({
    required this.jobId,
    required this.repository,
    super.key,
  });
  final String jobId;
  final JobMatchRepository repository;
  @override
  State<JobMatchScreen> createState() => _JobMatchScreenState();
}

class _JobMatchScreenState extends State<JobMatchScreen> {
  static const _tts = MethodChannel('enablework_plus/tts');
  bool _speaking = false;
  late Future<JobMatchResult> _request = widget.repository.matchJob(
    widget.jobId,
  );

  @override
  void dispose() {
    _stopReading();
    super.dispose();
  }

  Future<void> _stopReading() async {
    try {
      await _tts.invokeMethod<void>('stop');
    } on MissingPluginException {
      return;
    } on PlatformException {
      return;
    }
  }

  Future<void> _readAloud(JobMatchResult result) async {
    if (_speaking) {
      await _stopReading();
      if (mounted) setState(() => _speaking = false);
      return;
    }
    final text = [
      '${result.skillsOnly ? 'Skills comparison' : 'AI job fit review'}. ${result.summary}',
      'Matched skills. ${result.matchedSkills.join('. ')}',
      'Skills to check. ${result.skillGaps.join('. ')}',
      'Accessibility considerations. ${result.accessibilityConsiderations.join('. ')}',
    ].join(' ');
    try {
      await _tts.invokeMethod<void>('speak', {'text': text});
      if (mounted) setState(() => _speaking = true);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Read aloud is unavailable on this device.'),
          ),
        );
      }
    }
  }

  Widget _list(String title, List<String> values) => SectionCard(
    title: title,
    children: values.isEmpty
        ? [const Text('No items returned.')]
        : [
            for (final value in values)
              ListTile(contentPadding: EdgeInsets.zero, title: Text(value)),
          ],
  );
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Job fit review')),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const FslSectionGuide(GuideSection.fit),
        const Text(
          'This explains profile-to-job alignment. It is not a hiring score or decision.',
        ),
        FutureBuilder<JobMatchResult>(
          future: _request,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const BusyIndicator(label: 'Reviewing job fit securely');
            }
            if (snapshot.hasError) {
              return SectionCard(
                title: 'Job matching unavailable',
                children: [
                  Text(jobMatchFailure(snapshot.error!).message),
                  TextButton(
                    onPressed: () => setState(
                      () => _request = widget.repository.matchJob(widget.jobId),
                    ),
                    child: const Text('Try again'),
                  ),
                ],
              );
            }
            final result = snapshot.requireData;
            return Column(
              children: [
                if (result.skillsOnly)
                  const SectionCard(
                    title: 'Skills comparison',
                    children: [
                      Text(
                        'The AI review is unavailable. This comparison uses the skills listed in your profile and the posting.',
                      ),
                    ],
                  ),
                SectionCard(
                  title: 'Listen to this review',
                  children: [
                    const Text(
                      'Your phone will read this result aloud. No microphone or recording is used.',
                    ),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: () => _readAloud(result),
                      icon: Icon(
                        _speaking ? Icons.stop : Icons.volume_up,
                        size: 28,
                      ),
                      label: Text(
                        _speaking ? 'Stop reading' : 'Read results aloud',
                      ),
                    ),
                  ],
                ),
                _list('Summary', [result.summary]),
                _list('Matched skills', result.matchedSkills),
                _list(
                  result.skillsOnly
                      ? 'Listed job skills missing from your profile'
                      : 'Skills to check',
                  result.skillGaps,
                ),
                _list(
                  result.skillsOnly
                      ? 'Accessibility listed by the employer'
                      : 'Accessibility considerations',
                  result.accessibilityConsiderations,
                ),
              ],
            );
          },
        ),
      ],
    ),
  );
}
