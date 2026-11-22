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
    _tts.invokeMethod<void>('stop');
    super.dispose();
  }

  Future<void> _readAloud(JobMatchResult result) async {
    if (_speaking) {
      await _tts.invokeMethod<void>('stop');
      if (mounted) setState(() => _speaking = false);
      return;
    }
    final text = [
      'Job fit summary. ${result.summary}',
      'Matched skills. ${result.matchedSkills.join('. ')}',
      'Skill gaps. ${result.skillGaps.join('. ')}',
      'Accessibility considerations. ${result.accessibilityConsiderations.join('. ')}',
    ].join(' ');
    try {
      await _tts.invokeMethod<void>('speak', {'text': text});
      if (mounted) setState(() => _speaking = true);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Read aloud is unavailable on this device.')),
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
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      const CareerHeading('Job fit review'),
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
                const Text(
                  'No AI result was created. Your profile remains private.',
                ),
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
              SectionCard(
                title: 'Listen to this review',
                children: [
                  const Text('Your phone will read this result aloud. No microphone or recording is used.'),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: () => _readAloud(result),
                    icon: Icon(_speaking ? Icons.stop : Icons.volume_up, size: 28),
                    label: Text(_speaking ? 'Stop reading' : 'Read results aloud'),
                  ),
                ],
              ),
              _list('Summary', [result.summary]),
              _list('Matched skills', result.matchedSkills),
              _list('Skill gaps', result.skillGaps),
              _list(
                'Accessibility considerations',
                result.accessibilityConsiderations,
              ),
            ],
          );
        },
      ),
    ],
  );
}
