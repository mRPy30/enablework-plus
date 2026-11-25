import 'dart:async';

import '../widgets/voice_guidance.dart';
import 'fsl_section_guide.dart';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/career_preview.dart';
import '../models/seeker_workspace.dart';
import '../widgets/workspace_widgets.dart';

class JobsScreen extends StatefulWidget {
  const JobsScreen({required this.preview, required this.onOpen, super.key})
    : startWithVoice = false,
      focusSearch = false,
      loadJobs = null,
      onAccessLost = null;
  const JobsScreen.authenticated({
    this.startWithVoice = false,
    this.focusSearch = false,
    required this.loadJobs,
    required this.onOpen,
    required this.onAccessLost,
    super.key,
  }) : preview = null;
  final bool startWithVoice, focusSearch;
  final CareerPreview? preview;
  final Future<List<JobListing>> Function()? loadJobs;
  final VoidCallback? onAccessLost;
  final ValueChanged<JobListing> onOpen;
  @override
  State<JobsScreen> createState() => _JobsScreenState();
}

class _JobsScreenState extends State<JobsScreen> {
  final _search = TextEditingController();
  static const _voice = MethodChannel('enablework_plus/voice_search');
  bool _listening = false;

  @override
  void initState() {
    super.initState();
    if (widget.startWithVoice) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _voiceSearch();
      });
    }
  }

  Future<void> _voiceSearch() async {
    if (_listening) return;
    setState(() => _listening = true);
    String? message;
    try {
      final words = (await _voice.invokeMethod<String>('listen'))?.trim();
      if (!mounted || words == null) return;
      if (words.isEmpty) {
        message = 'No words recognized. Try again or type your search.';
      } else {
        _search.value = TextEditingValue(
          text: words,
          selection: TextSelection.collapsed(offset: words.length),
        );
        _announceResults();
      }
    } on PlatformException {
      message = 'Voice input unavailable. You can type your search.';
    } on MissingPluginException {
      message = 'Voice input unavailable. You can type your search.';
    } finally {
      if (mounted) {
        setState(() => _listening = false);
        if (message != null) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(message)));
        }
      }
    }
  }

  Timer? _feedback;
  void _announceResults() {
    _feedback?.cancel();
    if (!VoiceScope.of(context)) return;
    _feedback = Timer(const Duration(milliseconds: 650), () async {
      List<JobListing> jobs;
      try {
        jobs = await _request;
      } catch (_) {
        return; // The list already exposes its retry state.
      }
      if (!mounted ||
          !VoiceScope.of(context) ||
          ModalRoute.of(context)?.isCurrent != true ||
          !TickerMode.valuesOf(context).enabled) {
        return;
      }
      final count = jobs.where((j) => j.matches(_search.text, _work)).length;
      final filter = workArrangementLabels[_work] ?? 'All work arrangements';
      await speakVoice(
        context,
        '$filter. $count matching openings.',
        automatic: true,
      );
    });
  }

  String? _work;
  bool _showFilters = false;
  late Future<List<JobListing>> _request = _load();
  Future<List<JobListing>> _load() async {
    try {
      return await (widget.loadJobs?.call() ??
          Future.value(widget.preview!.jobs));
    } on WorkspaceFailure catch (e) {
      if (e.accessLost && mounted) widget.onAccessLost?.call();
      rethrow;
    }
  }

  @override
  void dispose() {
    _feedback?.cancel();
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<List<JobListing>>(
    future: _request,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const Center(child: BusyIndicator(label: 'Loading jobs'));
      }
      if (snapshot.hasError) {
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const CareerHeading('Find a job'),
            const FslSectionGuide(GuideSection.jobs),
            SectionCard(
              title: 'Jobs could not be loaded',
              children: [
                const Text('Check your connection and try again.'),
                TextButton(
                  onPressed: () => setState(() => _request = _load()),
                  child: const Text('Try again'),
                ),
              ],
            ),
          ],
        );
      }
      return _content(context, snapshot.requireData);
    },
  );

  Widget _content(BuildContext context, List<JobListing> jobs) {
    final matches = jobs.where((j) => j.matches(_search.text, _work)).toList();
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const CareerHeading('Find a job'),
        const FslSectionGuide(GuideSection.jobs),
        if (widget.loadJobs != null)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => setState(() => _request = _load()),
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh jobs'),
            ),
          ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              autofocus: widget.focusSearch,
              controller: _search,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                labelText: 'Search jobs',
                hintText: 'Title, company, city or skill',
                prefixIcon: const Icon(Icons.search),
                suffixIcon:
                    !kIsWeb && defaultTargetPlatform == TargetPlatform.android
                    ? IconButton(
                        tooltip: 'Search jobs by voice',
                        icon: const Icon(Icons.mic),
                        onPressed: _listening ? null : _voiceSearch,
                      )
                    : null,
              ),
              onChanged: (_) {
                setState(() {});
                _announceResults();
              },
            ),
          ),
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
                  onSelected: (_) {
                    setState(() => _work = option.key);
                    _announceResults();
                  },
                ),
            ],
          ),
        if (matches.isEmpty)
          Semantics(
            liveRegion: true,
            child: SectionCard(
              title: jobs.isEmpty ? 'No open jobs yet' : 'No matching jobs',
              children: [
                Text(
                  jobs.isEmpty
                      ? 'Published opportunities will appear here when available.'
                      : 'Try a different search or work arrangement.',
                ),
                TextButton(
                  onPressed: () => setState(() {
                    _search.clear();
                    _work = null;
                  }),
                  child: const Text('Clear search and filters'),
                ),
              ],
            ),
          )
        else ...[
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Semantics(
              liveRegion: true,
              child: Text(
                '${matches.length} ${matches.length == 1 ? 'opening' : 'openings'}',
                style: Theme.of(context).textTheme.labelLarge,
              ),
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
                Text(
                  job.accessibility.firstOrNull ??
                      'Accessibility details not provided.',
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () {
                      _feedback?.cancel();
                      widget.onOpen(job);
                    },
                    label: Text(
                      'View job',
                      semanticsLabel:
                          'View job: ${job.title} at ${job.company}',
                    ),
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
    this.onMatch,
    super.key,
  });
  final JobListing job;
  final bool applied;
  final VoidCallback onReview;
  final VoidCallback? onMatch;
  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      CareerHeading(job.title),
      if (androidVoice)
        VoiceActions(
          'Read job details aloud',
          [
            job.title,
            job.company,
            job.city,
            workArrangementLabels[job.arrangement] ?? job.arrangement,
            jobTypeLabels[job.employment] ?? job.employment,
            job.description,
            if (job.qualifications.isNotEmpty)
              'Qualifications: ${job.qualifications}',
            if (job.requiredSkills.isNotEmpty)
              'Required skills: ${job.requiredSkills.join(', ')}',
            if (job.accessibility.isNotEmpty)
              'Workplace accessibility: ${job.accessibility.join('. ')}',
            if (job.deadline != null)
              'Apply before ${MaterialLocalizations.of(context).formatFullDate(job.deadline!.toLocal())}',
          ].where((s) => s.trim().isNotEmpty).join('. '),
        ),
      const FslSectionGuide(GuideSection.job),
      Text(job.company, style: Theme.of(context).textTheme.titleLarge),
      Text(
        '${job.city} · ${workArrangementLabels[job.arrangement]} · ${jobTypeLabels[job.employment]}',
      ),
      const SizedBox(height: 24),
      SectionCard(title: 'About the role', children: [Text(job.description)]),
      if (job.qualifications.isNotEmpty)
        SectionCard(
          title: 'Qualifications',
          children: [Text(job.qualifications)],
        ),
      if (job.requiredSkills.isNotEmpty)
        SectionCard(
          title: 'Required skills',
          children: [Text(job.requiredSkills.join(', '))],
        ),
      if (job.deadline != null)
        Text(
          'Apply before ${MaterialLocalizations.of(context).formatFullDate(job.deadline!.toLocal())}',
        ),
      SectionCard(
        title: 'Workplace accessibility',
        children: [
          if (job.accessibility.isEmpty)
            const Text('Accessibility details not provided.'),
          for (final item in job.accessibility)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text('•  $item'),
            ),
        ],
      ),
      if (onMatch != null)
        OutlinedButton.icon(
          onPressed: () {
            stopVoice();
            onMatch!();
          },
          icon: const Icon(Icons.auto_awesome_outlined),
          label: const Text('Check job fit'),
        ),
      FilledButton(
        onPressed: applied || !job.acceptingApplications
            ? null
            : () {
                stopVoice();
                onReview();
              },
        child: Text(
          applied
              ? 'Application recorded'
              : !job.acceptingApplications
              ? 'Applications closed'
              : 'Review application',
        ),
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
    this.authenticated = false,
    this.busy = false,
    this.uncertain = false,
    this.message,
    this.onCheckStatus,
    super.key,
  });
  final JobListing job;
  final List<ResumeRecord> resumes;
  final VoidCallback onManage;
  final ValueChanged<String> onConfirm;
  final bool authenticated, busy, uncertain;
  final String? message;
  final VoidCallback? onCheckStatus;
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
        const FslSectionGuide(GuideSection.review),
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
              onChanged: (v) {
                if (!widget.busy) setState(() => _id = v);
              },
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
              onPressed: widget.busy ? null : widget.onManage,
              icon: const Icon(Icons.folder_open),
              label: const Text('Manage resumes'),
            ),
          ],
        ),
        Text(
          widget.authenticated
              ? 'Your selected resume will be attached to your application for administrator review.'
              : 'This application is saved for this session only and will not be sent to an employer.',
        ),
        if (widget.message != null)
          Semantics(liveRegion: true, child: Text(widget.message!)),
        if (widget.busy) const BusyIndicator(label: 'Checking application'),
        if (widget.uncertain)
          OutlinedButton(
            onPressed: widget.busy ? null : widget.onCheckStatus,
            child: const Text('Check application status'),
          ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: selected == null || widget.busy || widget.uncertain
              ? null
              : () => widget.onConfirm(selected),
          child: Text(
            widget.authenticated ? 'Submit application' : 'Save application',
          ),
        ),
      ],
    );
  }
}
