import 'package:flutter/material.dart';

import '../models/career_preview.dart';
import '../models/seeker_workspace.dart';
import '../widgets/workspace_widgets.dart';

class ApplicationsScreen extends StatefulWidget {
  const ApplicationsScreen({
    required this.preview,
    required this.revision,
    required this.onOpen,
    required this.browse,
    super.key,
  });
  final CareerPreview? preview;
  final int revision;
  final ValueChanged<SeekerApplication> onOpen;
  final VoidCallback browse;
  @override
  State<ApplicationsScreen> createState() => _ApplicationsScreenState();
}

class _ApplicationsScreenState extends State<ApplicationsScreen> {
  late Future<List<SeekerApplication>>? _request = widget.preview
      ?.applications();
  @override
  void didUpdateWidget(ApplicationsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.revision != oldWidget.revision ||
        widget.preview != oldWidget.preview) {
      _request = widget.preview?.applications();
    }
  }

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      const CareerHeading('Your applications'),
      if (_request == null)
        const SectionCard(
          title: 'Application history unavailable',
          children: [Text('Live application details are not connected yet.')],
        )
      else
        FutureBuilder<List<SeekerApplication>>(
          future: _request,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const BusyIndicator(label: 'Loading applications');
            }
            if (snapshot.hasError) {
              return SectionCard(
                title: 'Applications could not be loaded',
                children: [
                  TextButton(
                    onPressed: () => setState(() {
                      _request = widget.preview!.applications();
                    }),
                    child: const Text('Try again'),
                  ),
                ],
              );
            }
            final rows = snapshot.requireData;
            if (rows.isEmpty) {
              return SectionCard(
                title: 'No applications yet',
                children: [
                  const Text(
                    'Choose a job and review your resume to get started.',
                  ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: FilledButton.tonal(
                      onPressed: widget.browse,
                      child: const Text('Browse jobs'),
                    ),
                  ),
                ],
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final row in rows)
                  SectionCard(
                    title: row.job.title,
                    children: [
                      Text(row.job.company),
                      ApplicationStatus(row.status),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton(
                          onPressed: () => widget.onOpen(row),
                          child: const Text('View application'),
                        ),
                      ),
                    ],
                  ),
              ],
            );
          },
        ),
    ],
  );
}

class ApplicationStatus extends StatelessWidget {
  const ApplicationStatus(this.status, {super.key});
  final String status;
  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.centerLeft,
    child: Chip(
      avatar: const Icon(Icons.assignment_outlined),
      label: Text(applicationStatusLabels[status] ?? 'Status unavailable'),
    ),
  );
}

class ApplicationDetails extends StatelessWidget {
  const ApplicationDetails(this.application, {super.key});
  final SeekerApplication application;
  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      const CareerHeading('Application details'),
      SectionCard(
        title: application.job.title,
        children: [
          Text(application.job.company),
          Text(application.job.city),
          ApplicationStatus(application.status),
          Text(
            'Submitted on ${MaterialLocalizations.of(context).formatMediumDate(application.date)}',
          ),
        ],
      ),
      SectionCard(
        title: 'Submitted resume',
        children: [Text(application.resumeTitle)],
      ),
    ],
  );
}
