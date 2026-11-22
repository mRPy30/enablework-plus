import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../models/seeker_workspace.dart';
import '../state/seeker_controller.dart';
import '../widgets/workspace_widgets.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({
    required this.controller,
    required this.openResumes,
    super.key,
  });
  final SeekerController controller;
  final VoidCallback openResumes;
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _form = GlobalKey<FormState>();
  final _fields = {
    for (final key in profileFieldLabels.keys) key: TextEditingController(),
  };
  late SeekerProfile _base;
  List<String> _jobTypes = [], _workArrangements = [];
  bool _dirty = false;
  @override
  void initState() {
    super.initState();
    _hydrate(widget.controller.data!.profile);
  }

  void _hydrate(SeekerProfile value) {
    _base = value;
    for (final key in _fields.keys) {
      _fields[key]!.text = value.fields[key]!;
    }
    _jobTypes = [...value.jobTypes];
    _workArrangements = [...value.workArrangements];
    _dirty = false;
  }

  @override
  void didUpdateWidget(covariant ProfileScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    final value = widget.controller.data!.profile;
    if (!_dirty && value.updatedAt != _base.updatedAt) _hydrate(value);
  }

  @override
  void dispose() {
    for (final c in _fields.values) {
      c.dispose();
    }
    super.dispose();
  }

  Widget _field(String key, {int lines = 1}) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: TextFormField(
      key: ValueKey('profile_$key'),
      controller: _fields[key],
      minLines: lines,
      maxLines: lines == 1 ? 1 : lines + 2,
      maxLength: profileFieldLimits[key],
      enabled: !widget.controller.busy,
      keyboardType: key == 'phone'
          ? TextInputType.phone
          : lines > 1
          ? TextInputType.multiline
          : TextInputType.text,
      textCapitalization: key == 'phone'
          ? TextCapitalization.none
          : TextCapitalization.sentences,
      decoration: InputDecoration(
        labelText: profileFieldLabels[key],
        border: const OutlineInputBorder(),
        helperText: key == 'accommodation_needs'
            ? 'Share work adjustments you want to discuss. Medical details are not needed.'
            : null,
      ),
      validator: (value) => validateProfileField(key, value ?? ''),
      onChanged: (_) {
        _dirty = true;
      },
    ),
  );
  Widget _choices(
    Map<String, String> choices,
    List<String> selected,
    void Function(List<String>) change,
  ) => Wrap(
    spacing: 8,
    runSpacing: 8,
    children: [
      for (final entry in choices.entries)
        FilterChip(
          label: Text(entry.value),
          selected: selected.contains(entry.key),
          onSelected: widget.controller.busy
              ? null
              : (value) {
                  setState(() {
                    _dirty = true;
                    change(
                      value
                          ? [...selected, entry.key]
                          : selected.where((x) => x != entry.key).toList(),
                    );
                  });
                },
        ),
    ],
  );
  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final draft = SeekerProfile(
      userId: _base.userId,
      updatedAt: _base.updatedAt,
      fields: {
        for (final entry in _fields.entries) entry.key: entry.value.text,
      },
      jobTypes: _jobTypes,
      workArrangements: _workArrangements,
    );
    final saved = await widget.controller.saveProfile(draft);
    if (!mounted) return;
    if (saved) {
      setState(() => _hydrate(widget.controller.data!.profile));
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Profile saved.')));
    }
  }

  Future<void> _reload() async {
    if (_dirty) {
      final discard = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Discard unsaved edits?'),
          content: const Text('Reloading replaces the edits in this form.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Keep editing'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Reload'),
            ),
          ],
        ),
      );
      if (discard != true) return;
    }
    await widget.controller.load();
    if (mounted && widget.controller.data != null) {
      setState(() => _hydrate(widget.controller.data!.profile));
    }
  }

  Future<void> _pickPhoto() async {
    final picked = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'webp'],
    );
    if (picked == null || picked.path == null) return;
    final ext = picked.extension.toLowerCase();
    final contentType = ext == 'png'
        ? 'image/png'
        : ext == 'webp'
        ? 'image/webp'
        : 'image/jpeg';
    final image = PickedImage(
      await File(picked.path!).readAsBytes(),
      extension: ext,
      contentType: contentType,
    );
    final saved = await widget.controller.uploadProfilePhoto(image);
    if (!mounted) return;
    if (saved) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile photo updated.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) => Form(
    key: _form,
    child: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            onPressed: widget.openResumes,
            icon: const Icon(Icons.folder_open),
            label: const Text('Manage resumes'),
          ),
        ),
        const SizedBox(height: 12),
        SectionCard(
          title: 'Profile photo',
          children: [
            Center(
              child: CircleAvatar(
                radius: 52,
                backgroundImage: widget.controller.data?.profilePhoto == null
                    ? null
                    : NetworkImage(widget.controller.data!.profilePhoto!.url),
                child: widget.controller.data?.profilePhoto == null
                    ? const Icon(Icons.person, size: 48)
                    : null,
              ),
            ),
            const SizedBox(height: 8),
            const Text('JPEG, PNG, or WebP up to 20 MB. Stored privately and visible only to you.'),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: widget.controller.busy ? null : _pickPhoto,
              icon: const Icon(Icons.photo_camera),
              label: const Text('Choose profile photo'),
            ),
          ],
        ),
        SectionCard(
          title: 'Personal details',
          children: [
            _field('full_name'),
            _field('phone'),
            _field('city'),
            _field('province'),
          ],
        ),
        SectionCard(
          title: 'Professional profile',
          children: [
            _field('headline'),
            _field('summary', lines: 3),
            _field('education_summary', lines: 3),
            _field('experience_summary', lines: 3),
            _field('skills', lines: 2),
          ],
        ),
        SectionCard(
          title: 'Work preferences',
          children: [
            const Text('Employment types'),
            const SizedBox(height: 8),
            _choices(jobTypeLabels, _jobTypes, (value) => _jobTypes = value),
            const SizedBox(height: 20),
            const Text('Work arrangement'),
            const SizedBox(height: 8),
            _choices(
              workArrangementLabels,
              _workArrangements,
              (value) => _workArrangements = value,
            ),
            const SizedBox(height: 20),
            _field('accommodation_needs', lines: 3),
          ],
        ),
        FilledButton(
          onPressed: widget.controller.busy ? null : _save,
          child: const Padding(
            padding: EdgeInsets.all(12),
            child: Text('Save profile'),
          ),
        ),
        TextButton(
          onPressed: widget.controller.busy ? null : _reload,
          child: const Text('Reload profile'),
        ),
        const SizedBox(height: 24),
      ],
    ),
  );
}
