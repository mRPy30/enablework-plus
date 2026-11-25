import '../widgets/voice_guidance.dart';
import 'fsl_section_guide.dart';

import 'package:flutter/material.dart';

import '../models/seeker_workspace.dart';
import '../models/career_preview.dart';
import 'jobs_screen.dart';
import 'applications_screen.dart';
import '../services/seeker_repository.dart';
import '../services/career_repository.dart';
import 'authenticated_job_flow.dart';
import '../state/seeker_controller.dart';
import '../widgets/workspace_widgets.dart';
import 'dashboard_screen.dart';
import 'profile_screen.dart';
import 'resumes_screen.dart';
import 'accessibility_screen.dart';
import 'candidate_support_screen.dart';
import '../services/resume_scan_repository.dart';
import '../services/job_match_repository.dart';
import '../widgets/ai_assistant_sheet.dart';

class SeekerHome extends StatefulWidget {
  const SeekerHome({
    required this.repository,
    required this.onPreferences,
    required this.onAccessLost,
    required this.onSignOut,
    this.picker,
    this.onDisplay,
    this.preview,
    this.addSampleResume,
    super.key,
  });
  final SeekerRepository repository;
  final void Function(AccessibilityPreferences) onPreferences;
  final VoidCallback onAccessLost;
  final Future<void> Function() onSignOut;
  final PdfPicker? picker;
  final VoidCallback? onDisplay;
  final CareerPreview? preview;
  final VoidCallback? addSampleResume;
  @override
  State<SeekerHome> createState() => _SeekerHomeState();
}

class _SeekerHomeState extends State<SeekerHome> with WidgetsBindingObserver {
  late final SeekerController _controller;
  late final PdfPicker _picker;
  int _tab = 0;
  String? _sessionError;
  int _revision = 0;
  bool _careerBusy = false;
  bool get _busy => _controller.busy || _careerBusy;
  CareerRepository? get _career => widget.repository is CareerRepository
      ? widget.repository as CareerRepository
      : null;
  CandidateSupportRepository? get _support =>
      widget.repository is CandidateSupportRepository
      ? widget.repository as CandidateSupportRepository
      : null;
  final _pages = <Widget Function()>[];
  void _open(Widget Function() page) {
    stopVoice();
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _pages.add(page));
  }

  void _back() {
    stopVoice();
    setState(() => _pages.removeLast());
  }

  void _tabTo(int value) {
    if (_busy) return;
    stopVoice();
    setState(() {
      FocusManager.instance.primaryFocus?.unfocus();
      _pages.clear();
      _tab = value;
      if (value == 2) _revision++;
    });
  }

  void _resumes() => _open(
    () => ResumesScreen(
      controller: _controller,
      picker: _picker,
      addSample: widget.preview == null ? null : widget.addSampleResume,
      scanRepository: widget.repository is ResumeScanRepository
          ? widget.repository as ResumeScanRepository
          : null,
    ),
  );
  void _openPreviewJob(CareerPreview preview, JobListing job) => _open(
    () => JobDetails(
      job: job,
      applied: preview.alreadyApplied(job),
      onReview: () => _open(
        () => ApplicationReview(
          job: job,
          resumes: _controller.data!.resumes,
          onManage: _resumes,
          onConfirm: (id) async {
            try {
              preview.savePreview(job, id);
            } on WorkspaceFailure catch (e) {
              setState(() => _sessionError = e.message);
              return;
            }
            setState(() {
              _revision++;
              _pages.clear();
              _tab = 2;
            });
            await _controller.load();
          },
        ),
      ),
    ),
  );

  void _openLiveJob(JobListing job) => _open(
    () => AuthenticatedJobFlow(
      jobId: job.id,
      repository: _career!,
      resumes: _controller.data!.resumes,
      onManage: _resumes,
      onAccessLost: widget.onAccessLost,
      onBusy: (value) {
        if (mounted) setState(() => _careerBusy = value);
      },
      matcher: widget.repository is JobMatchRepository
          ? widget.repository as JobMatchRepository
          : null,
      onSubmitted: (application) {
        if (!mounted) return;
        final confirmation =
            'Application submitted for ${application.job.title}.';
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(confirmation)));
        if (_controller.data?.preferences.enabledFeatures.contains(
              'voice_guidance',
            ) ==
            true) {
          speakVoice(context, confirmation, automatic: true);
        }
        setState(() {
          _careerBusy = false;
          _revision++;
          _tab = 2;
          _pages.clear();
          _pages.add(() => ApplicationDetails(application, support: _support));
        });
        _controller.load();
      },
    ),
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _picker = widget.picker ?? DevicePdfPicker();
    _controller = SeekerController(
      widget.repository,
      onPreferences: widget.onPreferences,
      onAccessLost: widget.onAccessLost,
    )..load();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !_busy) {
      _controller.load();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    super.dispose();
  }

  Future<void> _signOut() async {
    try {
      await widget.onSignOut();
    } catch (_) {
      if (mounted) {
        setState(() => _sessionError = 'Unable to sign out. Please try again.');
      }
    }
  }

  void _openAssistant() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => AiAssistantSheet(
        matchingAvailable: widget.repository is JobMatchRepository,
        onScanResume: () {
          Navigator.pop(sheetContext);
          _resumes();
        },
        onFindMatch: () {
          Navigator.pop(sheetContext);
          _tabTo(1);
        },
        onBuildResume: () {
          Navigator.pop(sheetContext);
          _resumes();
        },
        onAccessibility: () {
          Navigator.pop(sheetContext);
          _tabTo(4);
        },
        onSignLanguage: () {
          Navigator.pop(sheetContext);
          _open(() => const SignLanguageSupportScreen());
        },
      ),
    );
  }

  void _notifications() {
    _open(
      () => _Notifications(
        load: _career?.loadApplications ?? widget.preview?.applications,
        onAccessLost: widget.onAccessLost,
        onOpen: (application) =>
            _open(() => ApplicationDetails(application, support: _support)),
      ),
    );
  }

  Widget _topBar(BuildContext context) {
    final data = _controller.data;
    final active = !_busy && data?.preferences.preferencesReviewed == true;
    final photo = data?.profilePhoto;
    return Material(
      color: Theme.of(context).colorScheme.surface,
      elevation: 2,
      shadowColor: Colors.black26,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          children: [
            Expanded(
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: TextButton.icon(
                  onPressed: _busy ? null : widget.onDisplay ?? () => _tabTo(4),
                  icon: const Icon(Icons.tune),
                  label: const Text('Display and controls'),
                ),
              ),
            ),
            IconButton(
              tooltip: 'Notifications',
              onPressed: active ? _notifications : null,
              icon: const Icon(Icons.notifications_outlined),
            ),
            IconButton(
              tooltip: 'Open profile',
              onPressed: active ? () => _tabTo(3) : null,
              icon: CircleAvatar(
                radius: 16,
                foregroundImage: photo == null ? null : NetworkImage(photo.url),
                child: const Icon(Icons.person_outline, size: 21),
              ),
            ),
            PopupMenuButton<String>(
              tooltip: 'Account options',
              enabled: !_busy,
              onSelected: (value) {
                if (value == 'refresh') {
                  _controller.load();
                } else {
                  _signOut();
                }
              },
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: 'refresh',
                  enabled: !_controller.loading,
                  child: const Text('Refresh your information'),
                ),
                PopupMenuItem(
                  value: 'sign-out',
                  child: Text(
                    widget.preview == null ? 'Sign out' : 'End session',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _controller,
    builder: (context, _) => VoiceScope(
      enabled:
          _controller.data?.preferences.enabledFeatures.contains(
            'voice_guidance',
          ) ??
          false,
      child: Stack(
        children: [
          Column(
            children: [
              _topBar(context),
              if (androidVoice &&
                  _pages.isEmpty &&
                  _controller.data?.preferences.preferencesReviewed == true &&
                  _controller.data!.preferences.enabledFeatures.contains(
                    'voice_guidance',
                  ))
                TabVoiceGuide(_tab),
              if (_pages.isNotEmpty)
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: BackButton(onPressed: _busy ? null : _back),
                ),
              if (_controller.error != null &&
                  (_controller.data == null ||
                      (_controller.data!.preferences.preferencesReviewed &&
                          (_tab != 4 || _pages.isNotEmpty))))
                WorkspaceError(
                  message: _controller.error!,
                  onDismiss: _controller.clearError,
                ),
              if (_sessionError != null)
                WorkspaceError(
                  message: _sessionError!,
                  onDismiss: () => setState(() => _sessionError = null),
                ),
              if (_controller.busy) BusyIndicator(label: _controller.progress),
              Expanded(
                child: _controller.data == null
                    ? _controller.loading
                          ? const Center(
                              child: BusyIndicator(
                                label: 'Loading your workspace',
                              ),
                            )
                          : Center(
                              child: Padding(
                                padding: const EdgeInsets.all(24),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Text(
                                      'Your workspace could not be loaded.',
                                    ),
                                    const SizedBox(height: 12),
                                    FilledButton(
                                      onPressed: _controller.load,
                                      child: const Text('Try again'),
                                    ),
                                  ],
                                ),
                              ),
                            )
                    : !_controller.data!.preferences.preferencesReviewed
                    ? AccessibilityScreen(
                        key: const ValueKey('accessibility_onboarding'),
                        controller: _controller,
                        onboarding: true,
                      )
                    : PopScope(
                        canPop: _pages.isEmpty,
                        onPopInvokedWithResult: (popped, _) {
                          if (!popped && _pages.isNotEmpty && !_busy) {
                            _back();
                          }
                        },
                        child: IndexedStack(
                          index: _pages.length,
                          children: [
                            IndexedStack(
                              index: _tab,
                              children: [
                                if (widget.preview case final preview?) ...[
                                  DashboardScreen(
                                    data: _controller.data!,
                                    demoJobs: preview.jobs,
                                    openJob: (job) =>
                                        _openPreviewJob(preview, job),
                                    openTab: _tabTo,
                                    openResumes: _resumes,
                                  ),
                                  JobsScreen(
                                    preview: preview,
                                    onOpen: (job) =>
                                        _openPreviewJob(preview, job),
                                  ),
                                  ApplicationsScreen(
                                    preview: preview,
                                    revision: _revision,
                                    browse: () => _tabTo(1),
                                    onOpen: (a) => _open(
                                      () => ApplicationDetails(
                                        a,
                                        support: _support,
                                      ),
                                    ),
                                  ),
                                ] else ...[
                                  DashboardScreen.authenticated(
                                    openSignSupport: () => _open(
                                      () => const SignLanguageSupportScreen(),
                                    ),
                                    startSearch: _career == null
                                        ? null
                                        : (voice) => _open(
                                            () => JobsScreen.authenticated(
                                              startWithVoice: voice,
                                              focusSearch: !voice,
                                              loadJobs: _career!.loadJobs,
                                              onOpen: _openLiveJob,
                                              onAccessLost: widget.onAccessLost,
                                            ),
                                          ),
                                    data: _controller.data!,
                                    openTab: _tabTo,
                                    openResumes: _resumes,
                                  ),
                                  if (_career case final career?)
                                    JobsScreen.authenticated(
                                      loadJobs: career.loadJobs,
                                      onOpen: _openLiveJob,
                                      onAccessLost: widget.onAccessLost,
                                    )
                                  else
                                    const _UnavailableCareerTab(
                                      heading: 'Find a job',
                                      title: 'Listings currently unavailable',
                                      message: 'Job listings will appear here once the service is available. Please try again later.',
                                    ),
                                  if (_career case final career?)
                                    ApplicationsScreen.authenticated(
                                      loadApplications: career.loadApplications,
                                      revision: _revision,
                                      browse: () => _tabTo(1),
                                      onAccessLost: widget.onAccessLost,
                                      onOpen: (a) => _open(
                                        () => ApplicationDetails(
                                          a,
                                          support: _support,
                                        ),
                                      ),
                                    )
                                  else
                                    const _UnavailableCareerTab(
                                      heading: 'Your applications',
                                      title: 'Application history unavailable',
                                      message: 'You can check your application totals on Home. Individual application details are currently unavailable.',
                                    ),
                                ],
                                ProfileScreen(
                                  controller: _controller,
                                  openResumes: _resumes,
                                ),
                                AccessibilityScreen(
                                  controller: _controller,
                                  active: _tab == 4 && _pages.isEmpty,
                                ),
                              ],
                            ),
                            for (final page in _pages) page(),
                          ],
                        ),
                      ),
              ),
              if (_controller.data?.preferences.preferencesReviewed ?? false)
                NavigationBar(
                  height:
                      80 +
                      (MediaQuery.textScalerOf(context).scale(12) - 12).clamp(
                            0,
                            60,
                          ) *
                          2,
                  selectedIndex: _tab,
                  animationDuration: MediaQuery.disableAnimationsOf(context)
                      ? Duration.zero
                      : const Duration(milliseconds: 200),
                  labelBehavior: MediaQuery.textScalerOf(context).scale(12) > 16
                      ? NavigationDestinationLabelBehavior.onlyShowSelected
                      : NavigationDestinationLabelBehavior.alwaysShow,
                  onDestinationSelected:
                      _controller.data == null || _controller.busy
                      ? null
                      : _tabTo,
                  destinations: const [
                    NavigationDestination(
                      icon: Icon(Icons.home_outlined),
                      selectedIcon: Icon(Icons.home),
                      label: 'Home',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.work_outline),
                      selectedIcon: Icon(Icons.work),
                      label: 'Jobs',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.assignment_outlined),
                      selectedIcon: Icon(Icons.assignment),
                      label: 'Applications',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.person_outline),
                      selectedIcon: Icon(Icons.person),
                      label: 'Profile',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.accessibility_new),
                      label: 'Settings',
                      tooltip: 'Accessibility preferences',
                    ),
                  ],
                ),
            ],
          ),
          if (_controller.data?.preferences.preferencesReviewed ?? false)
            Positioned(
              right: 16,
              bottom: 96,
              child: FloatingActionButton.extended(
                heroTag: 'enablework-assistant',
                onPressed: _busy ? null : _openAssistant,
                backgroundColor: Theme.of(context).colorScheme.error,
                foregroundColor: Theme.of(context).colorScheme.onError,
                icon: const Icon(Icons.auto_awesome),
                label: const Text('Assistant'),
                tooltip: 'Open EnableWork+ Assistant',
              ),
            ),
        ],
      ),
    ),
  );
}

class _UnavailableCareerTab extends StatelessWidget {
  const _UnavailableCareerTab({
    required this.heading,
    required this.title,
    required this.message,
  });

  final String heading;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      CareerHeading(heading),
      SectionCard(title: title, children: [Text(message)]),
    ],
  );
}

class _Notifications extends StatefulWidget {
  const _Notifications({
    required this.load,
    required this.onOpen,
    required this.onAccessLost,
  });
  final Future<List<SeekerApplication>> Function()? load;
  final ValueChanged<SeekerApplication> onOpen;
  final VoidCallback onAccessLost;
  @override
  State<_Notifications> createState() => _NotificationsState();
}

class _NotificationsState extends State<_Notifications> {
  late Future<List<SeekerApplication>> request = _load();
  Future<List<SeekerApplication>> _load() async {
    try {
      return await widget.load!();
    } on WorkspaceFailure catch (e) {
      if (mounted && e.accessLost) widget.onAccessLost();
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      const CareerHeading('Notifications'),
      const FslSectionGuide(GuideSection.notifications),
      if (widget.load == null)
        const Text('Application updates are unavailable.')
      else
        FutureBuilder<List<SeekerApplication>>(
          future: request,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const BusyIndicator(label: 'Loading application updates');
            }
            if (snapshot.hasError) {
              return Column(
                children: [
                  const Text('Could not load application updates.'),
                  TextButton(
                    onPressed: () => setState(() => request = _load()),
                    child: const Text('Try again'),
                  ),
                ],
              );
            }
            final rows = snapshot.requireData;
            if (rows.isEmpty) {
              return const Text(
                'No application updates yet. Your application statuses will appear here.',
              );
            }
            return SectionCard(
              title: 'Application status',
              children: [
                for (final row in rows)
                  ListTile(
                    title: Text(row.job.title),
                    subtitle: Text(
                      '${row.job.company} · ${applicationStatusLabels[row.status] ?? row.status}',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => widget.onOpen(row),
                  ),
              ],
            );
          },
        ),
    ],
  );
}
