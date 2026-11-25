import 'fsl_section_guide.dart';
import 'package:flutter/material.dart';

import '../models/seeker_workspace.dart';
import '../state/seeker_controller.dart';
import '../widgets/workspace_widgets.dart';

/// An accessible, structured resume editor backed by the seeker's own profile.
/// It deliberately does not create sample data or call an AI service.
class ResumeBuilderScreen extends StatefulWidget {
  const ResumeBuilderScreen({required this.controller, super.key});
  final SeekerController controller;

  @override
  State<ResumeBuilderScreen> createState() => _ResumeBuilderScreenState();
}

class _ResumeBuilderScreenState extends State<ResumeBuilderScreen> {
  final _form = GlobalKey<FormState>();
  final _fields = <String, TextEditingController>{};
  late SeekerProfile _base;
  bool _dirty = false;

  @override
  void initState() {
    super.initState();
    _hydrate(widget.controller.data!.profile);
  }

  void _hydrate(SeekerProfile profile) {
    _base = profile;
    for (final key in const [
      'full_name',
      'headline',
      'summary',
      'skills',
      'education_summary',
      'experience_summary',
      'accommodation_needs',
    ]) {
      final controller = _fields.putIfAbsent(key, TextEditingController.new);
      controller.text = profile.fields[key] ?? '';
    }
    _dirty = false;
  }

  @override
  void dispose() {
    for (final field in _fields.values) {
      field.dispose();
    }
    super.dispose();
  }

  Widget _field(String key, {int lines = 1, String? helperText}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: _fields[key],
        minLines: lines,
        maxLines: lines == 1 ? 1 : lines + 2,
        maxLength: profileFieldLimits[key],
        enabled: !widget.controller.busy,
        textCapitalization: TextCapitalization.sentences,
        decoration: InputDecoration(
          labelText: profileFieldLabels[key],
          helperText: helperText,
          border: const OutlineInputBorder(),
        ),
        validator: (value) => validateProfileField(key, value ?? ''),
        onChanged: (_) => _dirty = true,
      ),
    );
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final draft = SeekerProfile(
      userId: _base.userId,
      updatedAt: _base.updatedAt,
      fields: {
        for (final entry in _fields.entries) entry.key: entry.value.text,
        'phone': _base.fields['phone'] ?? '',
        'city': _base.fields['city'] ?? '',
        'province': _base.fields['province'] ?? '',
      },
      jobTypes: _base.jobTypes,
      workArrangements: _base.workArrangements,
    );
    final saved = await widget.controller.saveProfile(draft);
    if (!mounted || !saved) return;
    setState(() => _hydrate(widget.controller.data!.profile));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Accessible resume profile saved.')),
    );
  }

  @override
  Widget build(BuildContext context) => Form(
    key: _form,
    child: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const CareerHeading('Build your accessible resume'),
        const FslSectionGuide(GuideSection.builder),
        const Text(
          'Create a structured resume from your profile. You control every field, and nothing is sent to an AI service yet.',
        ),
        const SizedBox(height: 16),
        SectionCard(
          title: 'Identity and headline',
          children: [
            _field('full_name'),
            _field('headline', helperText: 'Use a short professional title.'),
          ],
        ),
        SectionCard(
          title: 'Professional summary',
          children: [_field('summary', lines: 4)],
        ),
        SectionCard(
          title: 'Education and experience',
          children: [
            _field('education_summary', lines: 4),
            _field('experience_summary', lines: 4),
          ],
        ),
        SectionCard(
          title: 'Skills and access needs',
          children: [
            _field(
              'skills',
              lines: 2,
              helperText: 'Separate skills with commas.',
            ),
            _field(
              'accommodation_needs',
              lines: 3,
              helperText: 'Describe workplace adjustments you want to discuss. Medical details are not needed.',
            ),
          ],
        ),
        FilledButton(
          onPressed: widget.controller.busy ? null : _save,
          child: const Padding(
            padding: EdgeInsets.all(12),
            child: Text('Save resume profile'),
          ),
        ),
        TextButton(
          onPressed: widget.controller.busy || !_dirty
              ? null
              : () => setState(() => _hydrate(_base)),
          child: const Text('Discard edits'),
        ),
      ],
    ),
  );
}
