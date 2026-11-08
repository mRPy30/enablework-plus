import 'package:flutter/material.dart';

import '../models/seeker_workspace.dart';
import '../widgets/workspace_widgets.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({required this.data, required this.openTab, super.key});
  final SeekerWorkspace data;
  final void Function(int) openTab;
  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      Semantics(
        header: true,
        child: Text(
          'Welcome, ${data.profile.fields['full_name']!.trim().isEmpty ? 'job seeker' : data.profile.fields['full_name']}',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
      ),
      const SizedBox(height: 8),
      const Text('Your next step starts here.'),
      const SizedBox(height: 24),
      SectionCard(
        title: 'Your profile',
        children: [
          Text('${data.profile.completionPercent}% complete'),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: data.profile.completionPercent / 100,
            semanticsLabel: 'Profile completeness',
            semanticsValue: '${data.profile.completionPercent}%',
          ),
          const SizedBox(height: 12),
          const Text(
            'Add your skills, background and preferred work. Phone and work adjustments are optional and do not affect this score.',
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.tonal(
              onPressed: () => openTab(1),
              child: const Text('Edit profile'),
            ),
          ),
        ],
      ),
      SectionCard(
        title: 'Current resume',
        children: [
          Text(data.currentResume?.title ?? 'No current resume selected.'),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.tonal(
              onPressed: () => openTab(2),
              child: const Text('Manage resumes'),
            ),
          ),
        ],
      ),
      SectionCard(
        title: 'Application activity',
        children: [
          Text(
            '${data.totalApplications} total applications',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final largeText = MediaQuery.textScalerOf(context).scale(16) > 22;
              final columns = largeText
                  ? 1
                  : constraints.maxWidth >= 600
                  ? 3
                  : constraints.maxWidth >= 360
                  ? 2
                  : 1;
              final width =
                  (constraints.maxWidth - 12 * (columns - 1)) / columns;
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  for (final status in applicationStatusLabels.entries)
                    SizedBox(
                      width: width,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: Theme.of(context)
                              .colorScheme
                              .surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${data.applicationCounts[status.key]}',
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineSmall,
                              ),
                              Text(status.value),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
          if (data.totalApplications == 0)
            const Padding(
              padding: EdgeInsets.only(top: 16),
              child: Text(
                'Your application activity will appear here after you apply.',
              ),
            ),
        ],
      ),
    ],
  );
}
