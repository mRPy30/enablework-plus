import 'package:flutter/material.dart';

import '../models/career_preview.dart';
import '../models/seeker_workspace.dart';
import '../services/career_repository.dart';
import '../widgets/workspace_widgets.dart';
import 'jobs_screen.dart';
import '../services/job_match_repository.dart';
import 'job_match_screen.dart';

class AuthenticatedJobFlow extends StatefulWidget {
  const AuthenticatedJobFlow({
    required this.jobId,
    required this.repository,
    required this.resumes,
    required this.onManage,
    required this.onSubmitted,
    required this.onAccessLost,
    required this.onBusy,
    this.matcher,
    super.key,
  });
  final String jobId;
  final CareerRepository repository;
  final List<ResumeRecord> resumes;
  final VoidCallback onManage, onAccessLost;
  final ValueChanged<bool> onBusy;
  final JobMatchRepository? matcher;
  final ValueChanged<SeekerApplication> onSubmitted;
  @override
  State<AuthenticatedJobFlow> createState() => _AuthenticatedJobFlowState();
}

class _AuthenticatedJobFlowState extends State<AuthenticatedJobFlow> {
  late Future<({JobListing job, bool applied})> _request = _load();
  bool _review = false, _busy = false, _uncertain = false;
  String? _message;
  Future<({JobListing job, bool applied})> _load() async {
    try {
      final job = await widget.repository.loadJob(widget.jobId);
      final application = await widget.repository.findApplication(widget.jobId);
      return (job: job, applied: application != null);
    } on WorkspaceFailure catch (e) {
      if (mounted && e.accessLost) widget.onAccessLost();
      rethrow;
    }
  }

  Future<void> _perform(String? resumeId) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    widget.onBusy(true);
    SeekerApplication? application;
    try {
      application = resumeId == null
          ? await widget.repository.findApplication(widget.jobId)
          : await widget.repository.submitApplication(widget.jobId, resumeId);
      if (mounted && application == null) {
        setState(
          () => _message =
              'No application has been confirmed yet. Check again shortly.',
        );
      }
    } catch (e) {
      if (!mounted) return;
      if (e is WorkspaceFailure && e.accessLost) {
        widget.onAccessLost();
        return;
      }
      setState(() {
        _uncertain =
            _uncertain || e is SubmissionUncertain || e is! WorkspaceFailure;
        _message = e is WorkspaceFailure
            ? e.message
            : 'Connection unavailable. Check your application status.';
      });
    } finally {
      if (mounted) {
        setState(() => _busy = false);
        widget.onBusy(false);
      }
    }
    if (mounted && application != null) widget.onSubmitted(application);
  }

  @override
  Widget build(BuildContext context) =>
      FutureBuilder<({JobListing job, bool applied})>(
        future: _request,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(
              child: BusyIndicator(label: 'Loading job details'),
            );
          }
          if (snapshot.hasError) {
            final error = snapshot.error;
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                SectionCard(
                  title: 'Job details unavailable',
                  children: [
                    Text(
                      error is WorkspaceFailure
                          ? error.message
                          : 'Check your connection and try again.',
                    ),
                    TextButton(
                      onPressed: () => setState(() => _request = _load()),
                      child: const Text('Try again'),
                    ),
                  ],
                ),
              ],
            );
          }
          final data = snapshot.requireData;
          if (!_review) {
            return JobDetails(
              job: data.job,
              applied: data.applied,
              onReview: () => setState(() => _review = true),
              onMatch: widget.matcher == null
                  ? null
                  : () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => JobMatchScreen(
                          jobId: data.job.id,
                          repository: widget.matcher!,
                        ),
                      ),
                    ),
            );
          }
          return ApplicationReview(
            job: data.job,
            resumes: widget.resumes,
            authenticated: true,
            busy: _busy,
            uncertain: _uncertain,
            message: _message,
            onManage: widget.onManage,
            onConfirm: _perform,
            onCheckStatus: () => _perform(null),
          );
        },
      );
}
