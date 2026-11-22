import 'package:flutter/material.dart';

import '../models/career_preview.dart';
import '../models/seeker_workspace.dart';
import '../widgets/workspace_widgets.dart';
import 'candidate_support_screen.dart';

class ApplicationsScreen extends StatefulWidget {
  const ApplicationsScreen({
    required this.preview,
    required this.revision,
    required this.onOpen,
    required this.browse,
    super.key,
  }) : loadApplications = null,
       onAccessLost = null;
  const ApplicationsScreen.authenticated({
    required this.loadApplications,
    required this.revision,
    required this.onOpen,
    required this.browse,
    required this.onAccessLost,
    super.key,
  }) : preview = null;
  final CareerPreview? preview;
  final Future<List<SeekerApplication>> Function()? loadApplications;
  final VoidCallback? onAccessLost;
  final int revision;
  final ValueChanged<SeekerApplication> onOpen;
  final VoidCallback browse;
  @override
  State<ApplicationsScreen> createState() => _ApplicationsScreenState();
}

class _ApplicationsScreenState extends State<ApplicationsScreen> {
  late Future<List<SeekerApplication>> _request = _load();
  Future<List<SeekerApplication>> _load() async {
    try {
      return await (widget.loadApplications?.call() ??
          widget.preview!.applications());
    } on WorkspaceFailure catch (e) {
      if (e.accessLost && mounted) widget.onAccessLost?.call();
      rethrow;
    }
  }

  @override
  void didUpdateWidget(ApplicationsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.revision != oldWidget.revision ||
        widget.preview != oldWidget.preview) {
      _request = _load();
    }
  }

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      const CareerHeading('Your applications'),
      if (widget.loadApplications != null)
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => setState(() => _request = _load()),
            icon: const Icon(Icons.refresh),
            label: const Text('Refresh applications'),
          ),
        ),
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
                    _request = _load();
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
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isPositive = status == 'accepted' || status == 'hired';
    final isAttention =
        status == 'review' ||
        status == 'under_review' ||
        status == 'shortlisted';
    return Align(
      alignment: Alignment.centerLeft,
      child: Chip(
        avatar: Icon(
          isPositive
              ? Icons.check_circle_outline
              : isAttention
              ? Icons.schedule_outlined
              : Icons.assignment_outlined,
          size: 18,
        ),
        backgroundColor: isPositive
            ? colors.secondaryContainer
            : isAttention
            ? colors.tertiaryContainer
            : colors.surfaceContainerHighest,
        label: Text(applicationStatusLabels[status] ?? 'Status unavailable'),
      ),
    );
  }
}

class ApplicationDetails extends StatelessWidget {
  const ApplicationDetails(this.application, {this.support, super.key});
  final SeekerApplication application;
  final CandidateSupportRepository? support;
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
      if (support != null && application.id != null)
        FilledButton.tonalIcon(
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => CandidateSupportScreen(
                applicationId: application.id!,
                repository: support!,
              ),
            ),
          ),
          icon: const Icon(Icons.support_agent_outlined),
          label: const Text('Messages, interviews and accommodations'),
        ),
    ],
  );
}
