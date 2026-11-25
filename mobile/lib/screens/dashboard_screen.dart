import 'fsl_section_guide.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

import '../models/career_preview.dart';
import '../models/seeker_workspace.dart';
import '../widgets/workspace_widgets.dart';
import '../widgets/welcome_guide.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({
    required this.data,
    required this.openTab,
    required this.openResumes,
    required this.openJob,
    this.startSearch,
    this.openSignSupport,
    this.demoJobs,
    super.key,
  });
  const DashboardScreen.authenticated({
    this.startSearch,
    this.openSignSupport,
    required this.data,
    required this.openTab,
    required this.openResumes,
    super.key,
  }) : demoJobs = null,
       openJob = null;

  final VoidCallback? openSignSupport;
  final void Function(bool voice)? startSearch;
  final SeekerWorkspace data;
  final VoidCallback openResumes;
  final ValueChanged<int> openTab;
  final ValueChanged<JobListing>? openJob;
  // Null in the authenticated app; an empty demo catalog is a distinct state.
  final List<JobListing>? demoJobs;

  @override
  Widget build(BuildContext context) {
    final jobs = demoJobs;
    final colors = Theme.of(context).colorScheme;
    final fullName = (data.profile.fields['full_name'] ?? '').trim();
    final firstName = fullName.isEmpty
        ? ''
        : fullName.split(RegExp(r'\s+')).first;
    final applicationOverview = <Widget>[
      const _Heading('Application overview'),
      SectionCard(
        borderless: true,
        title: data.totalApplications == 1
            ? '1 total application'
            : '${data.totalApplications} total applications',
        children: [
          if (data.totalApplications == 0)
            Text(
              jobs == null
                  ? 'Your application activity will appear here after you apply.'
                  : 'Your saved applications will appear here.',
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                for (final status in applicationStatusLabels.entries)
                  if ((data.applicationCounts[status.key] ?? 0) > 0)
                    Chip(
                      label: Text(
                        '${status.value}: ${data.applicationCounts[status.key]}',
                      ),
                    ),
              ],
            ),
          const SizedBox(height: 8),
          _Link('See all applications', () => openTab(2)),
        ],
      ),
    ];
    final accessibilityActions = <Widget>[
      if (openSignSupport != null &&
          data.preferences.accessibilityNeeds.any(
            const {'hearing', 'speech'}.contains,
          ))
        FilledButton.icon(
          onPressed: openSignSupport,
          icon: const Icon(Icons.sign_language_outlined),
          label: const Text('Filipino Sign Language'),
        ),
      if (startSearch != null &&
          data.preferences.accessibilityNeeds.any(
            const {'visual', 'mobility'}.contains,
          ) &&
          !kIsWeb &&
          defaultTargetPlatform == TargetPlatform.android)
        FilledButton.icon(
          onPressed: () => startSearch!(true),
          icon: const Icon(Icons.mic),
          label: const Text('Search jobs by voice'),
        ),
      if (startSearch != null &&
          data.preferences.accessibilityNeeds.any(
            const {'hearing', 'speech'}.contains,
          ))
        OutlinedButton.icon(
          onPressed: () => startSearch!(false),
          icon: const Icon(Icons.keyboard),
          label: const Text('Type a job search'),
        ),
      if (data.preferences.accessibilityNeeds.any(
        const {'learning', 'intellectual', 'psychosocial'}.contains,
      ))
        SectionCard(
          title: 'One step at a time',
          children: [
            const Text(
              'Start with a job title. Open one listing to read what the employer needs.',
            ),
            TextButton(
              onPressed: () => openTab(1),
              child: const Text('Browse jobs'),
            ),
          ],
        ),
    ];
    return ListView(
      key: const PageStorageKey('seeker-dashboard'),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        WelcomeGuide(name: firstName),
        const FslSectionGuide(GuideSection.home),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: () =>
              startSearch != null ? startSearch!(false) : openTab(1),
          icon: const Icon(Icons.search),
          label: const Text('Search jobs, companies or skills'),
          style: FilledButton.styleFrom(
            backgroundColor: colors.surface,
            foregroundColor: colors.onSurface,
            iconColor: colors.primary,
            side: BorderSide.none,
            alignment: Alignment.centerLeft,
            minimumSize: const Size.fromHeight(56),
          ),
        ),
        const SizedBox(height: 24),

        if (accessibilityActions.isNotEmpty) ...[
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 20,
            children: accessibilityActions,
          ),
          const SizedBox(height: 24),
        ],
        _ProfileCard(
          data: data,
          authenticated: jobs == null,
          edit: () => openTab(3),
        ),
        const _Heading('Quick actions'),
        LayoutBuilder(
          builder: (context, box) {
            final twoColumns =
                box.maxWidth >= 320 &&
                MediaQuery.textScalerOf(context).scale(14) <= 20;
            final width = twoColumns ? (box.maxWidth - 16) / 2 : box.maxWidth;
            return Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                for (final (icon, label, action)
                    in <(IconData, String, VoidCallback)>[
                      (Icons.search, 'Find jobs', () => openTab(1)),
                      (
                        Icons.assignment_outlined,
                        'My applications',
                        () => openTab(2),
                      ),
                      (
                        Icons.description_outlined,
                        'Manage resumes',
                        openResumes,
                      ),
                      (
                        Icons.accessibility_new,
                        'Accessibility settings',
                        () => openTab(4),
                      ),
                    ])
                  SizedBox(
                    width: width,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        alignment: Alignment.centerLeft,
                        minimumSize: const Size(0, 56),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        side: BorderSide.none,
                        backgroundColor: icon == Icons.assignment_outlined
                            ? colors.secondaryContainer
                            : icon == Icons.description_outlined
                            ? colors.tertiaryContainer
                            : colors.primaryContainer,
                        foregroundColor: icon == Icons.assignment_outlined
                            ? colors.onSecondaryContainer
                            : icon == Icons.description_outlined
                            ? colors.onTertiaryContainer
                            : colors.onPrimaryContainer,
                      ),
                      onPressed: action,
                      child: Row(
                        children: [
                          Icon(icon, size: 22),
                          const SizedBox(width: 9),
                          Flexible(child: Text(label)),
                        ],
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
        if (jobs == null) ...[
          ...applicationOverview,
          const _Heading('Job opportunities'),
          SectionCard(
            borderless: true,
            title: 'Find your next role',
            children: [
              const Text(
                'Explore openings and compare work arrangements, skills and accessibility details.',
              ),
              _Link('See all jobs', () => openTab(1)),
            ],
          ),
        ] else ...[
          const _Heading('Job opportunities'),
          if (jobs.isEmpty)
            const Text('No sample listings available.')
          else
            for (final job in jobs.take(2))
              _JobCard(job: job, open: () => openJob!(job)),
          _Link('See all jobs', () => openTab(1)),
          ...applicationOverview,
        ],
      ],
    );
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({
    required this.data,
    required this.authenticated,
    required this.edit,
  });
  final bool authenticated;
  final SeekerWorkspace data;
  final VoidCallback edit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context), colors = theme.colorScheme;
    final name = data.profile.fields['full_name']!.trim();
    final parts = name.split(RegExp(r'\s+'));
    final initials = name.isEmpty
        ? null
        : (parts.first.characters.first +
                  (parts.length > 1 ? parts.last.characters.first : ''))
              .toUpperCase();
    final percent = data.profile.completionPercent;
    final headline = data.profile.fields['headline']!.trim();
    final location =
        [data.profile.fields['city'], data.profile.fields['province']]
            .whereType<String>()
            .map((part) => part.trim())
            .where((part) => part.isNotEmpty)
            .join(', ');
    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: BorderSide.none,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ColoredBox(
            color: colors.primary,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      ExcludeSemantics(
                        child: CircleAvatar(
                          backgroundColor: colors.primaryContainer,
                          foregroundColor: colors.onPrimaryContainer,
                          child: initials == null
                              ? const Icon(Icons.person_outline)
                              : Padding(
                                  padding: const EdgeInsets.all(4),
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Text(initials),
                                  ),
                                ),
                        ),
                      ),
                      if (authenticated && location.isNotEmpty) ...[
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            location,
                            style: theme.textTheme.labelLarge?.copyWith(
                              color: colors.onPrimary,
                            ),
                            textAlign: TextAlign.end,
                          ),
                        ),
                      ],
                      if (!authenticated)
                        ExcludeSemantics(
                          child: Icon(
                            Icons.notifications_none_outlined,
                            color: colors.onPrimary,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Semantics(
                    header: true,
                    child: Text(
                      name.isEmpty && authenticated
                          ? 'Welcome back'
                          : 'Welcome, ${name.isEmpty ? 'job seeker' : name}',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        color: colors.onPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  if (headline.isNotEmpty)
                    Text(
                      headline,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colors.onPrimary,
                      ),
                    ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 20,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Semantics(
                      header: true,
                      child: Text(
                        'Profile readiness',
                        style: theme.textTheme.titleMedium,
                      ),
                    ),
                    Text(
                      '$percent% complete',
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: colors.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: percent / 100,
                  minHeight: 6,
                  borderRadius: BorderRadius.circular(6),
                  semanticsLabel: 'Profile completeness',
                  semanticsValue: '$percent%',
                ),
                const SizedBox(height: 10),
                Text(
                  percent == 100 ? 'Your profile is complete.' : 'Add your skills and background to complete your profile.',
                ),
                FilledButton.tonal(
                  onPressed: edit,
                  child: Text(
                    authenticated && percent < 100
                        ? 'Complete profile'
                        : 'Edit profile',
                  ),
                ),
                const Divider(height: 20),
                Row(
                  children: [
                    Icon(
                      Icons.description_outlined,
                      size: 20,
                      color: colors.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        data.currentResume == null
                            ? 'No current resume selected.'
                            : 'Current resume: ${data.currentResume!.title}',
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _JobCard extends StatelessWidget {
  const _JobCard({required this.job, required this.open});
  final JobListing job;
  final VoidCallback open;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context), colors = theme.colorScheme;
    final accessibility = job.accessibility
        .where((s) => s.trim().isNotEmpty)
        .join(' · ');
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                color: colors.secondaryContainer,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Text(
                  'Sample listing',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colors.onSecondaryContainer,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Semantics(
              header: true,
              child: Text(job.title, style: theme.textTheme.titleLarge),
            ),
            Text(
              [job.company, job.city].where((s) => s.isNotEmpty).join(' · '),
            ),
            const SizedBox(height: 4),
            Text(
              [
                jobTypeLabels[job.employment],
                workArrangementLabels[job.arrangement],
              ].nonNulls.join(' · '),
              style: theme.textTheme.labelLarge,
            ),
            const Divider(height: 20),
            Text(
              'Workplace accessibility: ${accessibility.isEmpty ? 'Not provided' : accessibility}',
            ),
            _Link('View job details', open),
          ],
        ),
      ),
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading(this.label);
  final String label;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(0, 22, 0, 10),
    child: Semantics(
      header: true,
      child: Text(
        label,
        style: Theme.of(context).textTheme.titleLarge
            ?.copyWith(fontWeight: FontWeight.w600),
      ),
    ),
  );
}

class _Link extends StatelessWidget {
  const _Link(this.label, this.action);
  final String label;
  final VoidCallback action;
  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.centerLeft,
    child: TextButton.icon(
      onPressed: action,
      icon: const Icon(Icons.arrow_forward, size: 18),
      iconAlignment: IconAlignment.end,
      label: Text(label),
    ),
  );
}
