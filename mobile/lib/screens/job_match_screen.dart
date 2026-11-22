import 'package:flutter/material.dart';

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
  late Future<JobMatchResult> _request = widget.repository.matchJob(
    widget.jobId,
  );
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
