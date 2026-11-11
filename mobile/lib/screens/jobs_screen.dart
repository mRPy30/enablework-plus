import 'package:flutter/material.dart';

import '../models/career_preview.dart';
import '../models/seeker_workspace.dart';
import '../widgets/workspace_widgets.dart';

class JobsScreen extends StatefulWidget {
  const JobsScreen({required this.preview, required this.onOpen, super.key});
  final CareerPreview? preview;
  final ValueChanged<JobListing> onOpen;
  @override
  State<JobsScreen> createState() => _JobsScreenState();
}

class _JobsScreenState extends State<JobsScreen> {
  final _search = TextEditingController();
  String? _work;
  bool _showFilters = false;
  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final source = widget.preview;
    final matches = source?.jobs
        .where((j) => j.matches(_search.text, _work))
        .toList();
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const CareerHeading('Find a job'),
        TextField(
          controller: _search,
          textInputAction: TextInputAction.search,
          decoration: const InputDecoration(
            labelText: 'Search jobs',
            hintText: 'Title, company or city',
            prefixIcon: Icon(Icons.search),
          ),
          onChanged: (_) => setState(() {}),
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            icon: const Icon(Icons.tune),
            label: Text(
              _work == null
                  ? 'Work arrangement'
                  : 'Work arrangement: ${workArrangementLabels[_work]}',
            ),
            onPressed: () => setState(() => _showFilters = !_showFilters),
          ),
        ),
        if (_showFilters)
          Wrap(
            spacing: 8,
            children: [
              for (final option in [
                const MapEntry<String?, String>(null, 'All'),
                ...workArrangementLabels.entries,
              ])
                ChoiceChip(
                  label: Text(option.value),
                  selected: _work == option.key,
                  onSelected: (_) => setState(() => _work = option.key),
                ),
            ],
          ),
        if (matches == null)
          const SectionCard(
            title: 'Job listings unavailable',
            children: [Text('Live job listings are not connected yet.')],
          )
        else if (matches.isEmpty)
          SectionCard(
            title: 'No matching jobs',
            children: [
              const Text('Try a different search or work arrangement.'),
              TextButton(
                onPressed: () => setState(() {
                  _search.clear();
                  _work = null;
                }),
                child: const Text('Clear search and filters'),
              ),
            ],
          )
        else ...[
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              '${matches.length} ${matches.length == 1 ? 'opening' : 'openings'}',
              style: Theme.of(context).textTheme.labelLarge,
            ),
          ),
          for (final job in matches)
            SectionCard(
              title: job.title,
              children: [
                Text(
                  job.company,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 6),
                Text(
                  '${job.city} · ${workArrangementLabels[job.arrangement]} · ${jobTypeLabels[job.employment]}',
                ),
                const Divider(height: 28),
                Text(job.accessibility.first),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () => widget.onOpen(job),
                    label: const Text('View job'),
                    icon: const Icon(Icons.arrow_forward),
                  ),
                ),
              ],
            ),
        ],
      ],
    );
  }
}

class JobDetails extends StatelessWidget {
  const JobDetails({
    required this.job,
    required this.applied,
    required this.onReview,
    super.key,
  });
  final JobListing job;
  final bool applied;
  final VoidCallback onReview;
  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      CareerHeading(job.title),
      Text(job.company, style: Theme.of(context).textTheme.titleLarge),
      Text(
        '${job.city} · ${workArrangementLabels[job.arrangement]} · ${jobTypeLabels[job.employment]}',
      ),
      const SizedBox(height: 24),
      SectionCard(title: 'About the role', children: [Text(job.description)]),
      SectionCard(
        title: 'Workplace accessibility',
        children: [
          for (final item in job.accessibility)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text('•  $item'),
            ),
        ],
      ),
      FilledButton(
        onPressed: applied ? null : onReview,
        child: Text(applied ? 'Application recorded' : 'Review application'),
      ),
    ],
  );
}

class ApplicationReview extends StatefulWidget {
  const ApplicationReview({
    required this.job,
    required this.resumes,
    required this.onManage,
    required this.onConfirm,
    super.key,
  });
  final JobListing job;
  final List<ResumeRecord> resumes;
  final VoidCallback onManage;
  final ValueChanged<String> onConfirm;
  @override
  State<ApplicationReview> createState() => _ApplicationReviewState();
}

class _ApplicationReviewState extends State<ApplicationReview> {
  String? _id;
  @override
  void initState() {
    super.initState();
    _id = widget.resumes
        .where((r) => r.isCurrent && r.canSelect)
        .firstOrNull
        ?.id;
  }

  @override
  Widget build(BuildContext context) {
    final ready = widget.resumes.where((r) => r.canSelect);
    final selected = ready.any((r) => r.id == _id) ? _id : null;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const CareerHeading('Review application'),
        SectionCard(
          title: widget.job.title,
          children: [Text(widget.job.company), Text(widget.job.city)],
        ),
        SectionCard(
          title: 'Choose a resume',
          children: [
            if (ready.isEmpty)
              const Text('Add an available resume before continuing.'),
            RadioGroup<String>(
              groupValue: selected,
              onChanged: (v) => setState(() => _id = v),
              child: Column(
                children: [
                  for (final r in ready)
                    RadioListTile<String>(
                      value: r.id,
                      title: Text(r.title),
                      subtitle: r.isCurrent
                          ? const Text('Current resume')
                          : null,
                    ),
                ],
              ),
            ),
            TextButton.icon(
              onPressed: widget.onManage,
              icon: const Icon(Icons.folder_open),
              label: const Text('Manage resumes'),
            ),
          ],
        ),
        const Text(
          'This demo application stays in this session. No employer receives it.',
        ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: selected == null ? null : () => widget.onConfirm(selected),
          child: const Text('Save demo application'),
        ),
      ],
    );
  }
}
