import 'package:flutter/material.dart';

import '../services/resume_scan_repository.dart';
import '../widgets/workspace_widgets.dart';

class ResumeScanScreen extends StatefulWidget {
  const ResumeScanScreen({
    required this.resumeId,
    required this.repository,
    super.key,
  });
  final String resumeId;
  final ResumeScanRepository repository;

  @override
  State<ResumeScanScreen> createState() => _ResumeScanScreenState();
}

class _ResumeScanScreenState extends State<ResumeScanScreen> {
  late Future<ResumeScanResult> _scan = widget.repository.scanResume(
    widget.resumeId,
  );

  Widget _list(String title, List<String> values) => SectionCard(
    title: title,
    children: values.isEmpty
        ? [const Text('No findings were returned.')]
        : [
            for (final value in values)
              ListTile(contentPadding: EdgeInsets.zero, title: Text(value)),
          ],
  );

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      const CareerHeading('Resume scan results'),
      const Text(
        'This review provides writing and accessibility suggestions. It is not a hiring decision or a protected-characteristic assessment.',
      ),
      FutureBuilder<ResumeScanResult>(
        future: _scan,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const BusyIndicator(label: 'Reviewing your resume securely');
          }
          if (snapshot.hasError) {
            return SectionCard(
              title: 'Scan unavailable',
              children: [
                const Text(
                  'No AI result was created. Your resume remains private.',
                ),
                TextButton(
                  onPressed: () => setState(
                    () => _scan = widget.repository.scanResume(widget.resumeId),
                  ),
                  child: const Text('Try again'),
                ),
              ],
            );
          }
          final result = snapshot.requireData;
          return Column(
            children: [
              _list('Strengths', result.strengths),
              _list('Missing sections', result.missingSections),
              _list('Detected skills', result.skills),
              _list('Readability notes', result.readabilityNotes),
              _list('Accessibility notes', result.accessibilityNotes),
            ],
          );
        },
      ),
    ],
  );
}
