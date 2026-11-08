import 'package:flutter/material.dart';

import '../models/seeker_workspace.dart';
import '../state/seeker_controller.dart';
import '../widgets/workspace_widgets.dart';
import '../utils/preference_text_scaler.dart';

class AccessibilityScreen extends StatefulWidget {
  const AccessibilityScreen({required this.controller, super.key});
  final SeekerController controller;
  @override
  State<AccessibilityScreen> createState() => _AccessibilityScreenState();
}

class _AccessibilityScreenState extends State<AccessibilityScreen> {
  late double _scale;
  late bool _contrast, _motion;
  bool _dirty = false;
  @override
  void initState() {
    super.initState();
    _hydrate();
  }

  void _hydrate() {
    final p = widget.controller.data!.preferences;
    _scale = p.textScale;
    _contrast = p.highContrast;
    _motion = p.reduceMotion;
    _dirty = false;
  }

  @override
  void didUpdateWidget(covariant AccessibilityScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_dirty) _hydrate();
  }

  Future<void> _save() async {
    final saved = await widget.controller.savePreferences(
      AccessibilityPreferences(
        textScale: _scale,
        highContrast: _contrast,
        reduceMotion: _motion,
      ),
    );
    if (mounted && saved) {
      setState(_hydrate);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Accessibility preferences saved.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      SectionCard(
        title: 'Accessibility',
        children: [
          const Text(
            'Adjust your reading and motion preferences. Android’s accessibility settings are also respected.',
          ),
          const SizedBox(height: 20),
          Text('App text size: ${(_scale * 100).round()}%'),
          Slider(
            value: _scale,
            min: 0.8,
            max: 2,
            divisions: 24,
            label: '${(_scale * 100).round()}%',
            semanticFormatterCallback: (value) =>
                '${(value * 100).round()} percent',
            onChanged: widget.controller.busy
                ? null
                : (value) => setState(() {
                    _dirty = true;
                    _scale = value;
                  }),
          ),
          Builder(
            builder: (context) {
              final current = MediaQuery.textScalerOf(context);
              return Text(
                'Text size preview',
                textScaler: PreferenceTextScaler(
                  current is PreferenceTextScaler ? current.system : current,
                  _scale,
                ),
                style: const TextStyle(fontSize: 16),
              );
            },
          ),
          const SizedBox(height: 16),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('High contrast'),
            subtitle: const Text(
              'Increase contrast between text and surfaces.',
            ),
            value: _contrast,
            onChanged: widget.controller.busy
                ? null
                : (value) => setState(() {
                    _dirty = true;
                    _contrast = value;
                  }),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Reduce motion'),
            subtitle: const Text('Reduce transitions and animated feedback.'),
            value: _motion,
            onChanged: widget.controller.busy
                ? null
                : (value) => setState(() {
                    _dirty = true;
                    _motion = value;
                  }),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: widget.controller.busy ? null : _save,
            child: const Text('Save preferences'),
          ),
        ],
      ),
    ],
  );
}
