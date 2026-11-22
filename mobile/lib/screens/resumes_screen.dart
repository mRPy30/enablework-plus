import 'package:flutter/material.dart';

import '../models/seeker_workspace.dart';
import '../services/seeker_repository.dart';
import '../state/seeker_controller.dart';
import '../widgets/workspace_widgets.dart';
import 'resume_builder_screen.dart';
import 'resume_scan_screen.dart';
import '../services/resume_scan_repository.dart';

class ResumesScreen extends StatefulWidget {
  const ResumesScreen({
    required this.controller,
    required this.picker,
    this.addSample,
    this.scanRepository,
    super.key,
  });
  final SeekerController controller;
  final PdfPicker picker;
  final VoidCallback? addSample;
  final ResumeScanRepository? scanRepository;
  @override
  State<ResumesScreen> createState() => _ResumesScreenState();
}

class _ResumesScreenState extends State<ResumesScreen> {
  final _title = TextEditingController(text: 'My resume');
  bool _picking = false;
  String? _error;
  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  Future<void> _upload() async {
    if (_title.text.trim().isEmpty || _title.text.trim().length > 180) {
      setState(() => _error = 'Enter a resume title of up to 180 characters.');
      return;
    }
    setState(() {
      _picking = true;
      _error = null;
    });
    try {
      final pdf = await widget.picker.pick();
      if (!mounted || pdf == null) return;
      final saved = await widget.controller.upload(_title.text, pdf);
      if (mounted && saved) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Resume uploaded and validated. You can now make it current.',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(
          () => _error = e is WorkspaceFailure
              ? e.message
              : 'Unable to read the selected PDF. Please try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  Future<void> _remove(ResumeRecord value) async {
    final remove = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove resume?'),
        content: Text(
          'Remove “${value.title}”? Resumes already submitted with an application are retained.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep resume'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (remove == true) {
      final removed = await widget.controller.remove(value.id);
      if (mounted && removed) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Resume removed.')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final busy = widget.controller.busy || _picking;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (widget.addSample != null)
          SectionCard(
            title: 'Sample resumes',
            children: [
              const Text(
                'Use a sample document for this session. No personal file is needed.',
              ),
              FilledButton.tonal(
                onPressed: busy
                    ? null
                    : () async {
                        widget.addSample!();
                        await widget.controller.load();
                      },
                child: const Text('Add sample resume'),
              ),
            ],
          )
        else
          SectionCard(
            title: 'Add a resume',
            children: [
              OutlinedButton.icon(
                onPressed: busy
                    ? null
                    : () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => ResumeBuilderScreen(
                            controller: widget.controller,
                          ),
                        ),
                      ),
                icon: const Icon(Icons.edit_document),
                label: const Text('Build an accessible resume'),
              ),
              const SizedBox(height: 12),
              const Text(
                'Choose a PDF up to 5 MiB. Each upload creates a separate version.',
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _title,
                enabled: !busy,
                maxLength: 180,
                decoration: const InputDecoration(
                  labelText: 'Resume title',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: busy ? null : _upload,
                icon: const Icon(Icons.upload_file),
                label: const Text('Choose PDF and upload'),
              ),
              if (_picking && !widget.controller.busy)
                const BusyIndicator(label: 'Reading your PDF'),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Semantics(liveRegion: true, child: Text(_error!)),
                ),
            ],
          ),
        if (widget.controller.data!.resumes.isEmpty)
          SectionCard(
            title: 'Your resumes',
            children: [
              Text(
                widget.addSample == null
                    ? 'No resumes yet. Upload a PDF to get started.'
                    : 'No resumes yet. Add a sample to get started.',
              ),
            ],
          ),
        for (final r in widget.controller.data!.resumes)
          SectionCard(
            title: r.title,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  Chip(label: Text(r.statusLabel)),
                  if (r.isCurrent) const Chip(label: Text('Current resume')),
                  if (r.isSubmitted)
                    const Chip(label: Text('Used in an application')),
                ],
              ),
              if (r.sizeBytes != null)
                Text('${(r.sizeBytes! / 1024).ceil()} KiB · PDF'),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (r.canSelect && !r.isCurrent)
                    OutlinedButton(
                      onPressed: busy
                          ? null
                          : () => widget.controller.setCurrent(r.id),
                      child: const Text('Make current'),
                    ),
                  if (r.status == ResumeStatus.pending)
                    OutlinedButton(
                      onPressed: busy
                          ? null
                          : () => widget.controller.retryValidation(r.id),
                      child: const Text('Retry validation'),
                    ),
                  if (r.canRemove)
                    TextButton(
                      onPressed: busy ? null : () => _remove(r),
                      child: Text(
                        r.status == ResumeStatus.deleting
                            ? 'Finish removal'
                            : 'Remove',
                      ),
                    ),
                ],
              ),
              if (widget.scanRepository != null &&
                  r.status == ResumeStatus.ready)
                OutlinedButton.icon(
                  onPressed: busy
                      ? null
                      : () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => ResumeScanScreen(
                              resumeId: r.id,
                              repository: widget.scanRepository!,
                            ),
                          ),
                        ),
                  icon: const Icon(Icons.auto_awesome_outlined),
                  label: const Text('Scan this resume'),
                ),
              if (r.isSubmitted)
                const Text(
                  'This version is retained with your submitted applications.',
                ),
            ],
          ),
      ],
    );
  }
}
