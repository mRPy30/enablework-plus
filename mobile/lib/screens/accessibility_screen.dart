import 'package:flutter/material.dart';

import '../models/seeker_workspace.dart';
import '../state/seeker_controller.dart';
import '../widgets/workspace_widgets.dart';
import '../utils/preference_text_scaler.dart';

/// One preference flow, entered after Auth for onboarding or from Settings.
class AccessibilityScreen extends StatefulWidget {
  const AccessibilityScreen({
    required this.controller,
    this.onboarding = false,
    this.active = true,
    super.key,
  });
  final SeekerController controller;
  final bool onboarding, active;
  @override
  State<AccessibilityScreen> createState() => _AccessibilityScreenState();
}

class _AccessibilityScreenState extends State<AccessibilityScreen> {
  static const _needs = <String, (String, String)>{
    'visual': ('Visual', 'Support for seeing or reading content.'),
    'mobility': ('Mobility', 'Support for movement or using touch controls.'),
    'hearing': ('Hearing', 'Support for hearing sounds or spoken information.'),
    'speech': ('Speech', 'Ways to interact without speaking.'),
    'intellectual': (
      'Intellectual',
      'Support for understanding information and tasks.',
    ),
    'learning': (
      'Learning',
      'Support for reading, learning or processing information.',
    ),
    'psychosocial': (
      'Psychosocial',
      'A calm experience with time and flexibility.',
    ),
  };
  static const _featureNames = <String, String>{
    'voice_guidance': 'Voice guidance',
    'text_to_speech': 'Text-to-speech',
    'voice_search': 'Voice search',
    'simplified_language': 'Simplified language',
    'step_by_step_guidance': 'Step-by-step guidance',
  };
  final _scroll = ScrollController();
  late AccessibilityPreferences _basePreferences;
  late double _scale;
  late bool _contrast, _motion;
  late Set<String> _selectedNeeds;
  late int _step;
  bool _dirty = false, _saving = false;
  String? _message;
  bool get _disabled =>
      _saving || widget.controller.busy || widget.controller.loading;

  @override
  void initState() {
    super.initState();
    _step = widget.onboarding ? 0 : -1;
    _hydrate();
  }

  void _hydrate() {
    final p = widget.controller.data!.preferences;
    _basePreferences = p;
    _selectedNeeds = p.accessibilityNeeds.toSet();
    _scale = p.textScale;
    _contrast = p.highContrast;
    _motion = p.reduceMotion;
    _dirty = false;
  }

  @override
  void didUpdateWidget(covariant AccessibilityScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Never replace an in-progress draft/version after a background refresh.
    if (!_dirty && !_saving) _hydrate();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _go(int step) {
    if (_disabled) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _step = step;
      _message = null;
    });
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  void _cancel() {
    if (_disabled) return;
    widget.controller.clearError();
    setState(() {
      _hydrate();
      _step = widget.onboarding ? 0 : -1;
      _message = widget.onboarding
          ? 'Nothing was saved. Continue when ready, or sign out.'
          : 'Changes cancelled. Your saved preferences are unchanged.';
    });
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  Future<void> _reload() async {
    if (_disabled) return;
    await widget.controller.load();
    if (!mounted ||
        widget.controller.data == null ||
        widget.controller.error != null) {
      return;
    }
    setState(() {
      _hydrate();
      _step = widget.onboarding ? 0 : -1;
      _message = 'Saved preferences reloaded. The draft was discarded.';
    });
  }

  Future<void> _confirm() async {
    if (_disabled) return;
    setState(() {
      _saving = true;
      _message = null;
    });
    final saved = await widget.controller.savePreferences(
      _basePreferences.copyWith(
        textScale: _scale,
        highContrast: _contrast,
        reduceMotion: _motion,
        accessibilityNeeds: _needs.keys.where(_selectedNeeds.contains).toList(),
        preferencesReviewed: true,
      ),
    );
    if (!mounted) return;
    setState(() {
      _saving = false;
      if (saved) {
        _hydrate();
        _step = -1;
      }
      _message = saved
          ? 'Accessibility preferences confirmed and saved.'
          : 'Preferences were not confirmed. Check the message and try again.';
    });
    if (saved) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Accessibility preferences confirmed and saved.'),
        ),
      );
    }
  }

  List<Widget> _featureControls() => [
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
      semanticFormatterCallback: (value) => '${(value * 100).round()} percent',
      onChanged: _disabled
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
      subtitle: const Text('Increase contrast between text and surfaces.'),
      value: _contrast,
      onChanged: _disabled
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
      onChanged: _disabled
          ? null
          : (value) => setState(() {
              _dirty = true;
              _motion = value;
            }),
    ),
  ];
  Widget _assessment() => SectionCard(
    title: 'Accessibility assessment',
    children: [
      const Text(
        'Choose any needs you want to share. You can choose more than one, or none. You can change these later in Settings.',
      ),
      const SizedBox(height: 12),
      const Text(
        'These choices stay private. Choosing a need does not turn on any features.',
      ),
      for (final need in _needs.entries)
        CheckboxListTile(
          key: ValueKey('need_${need.key}'),
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          title: Text(need.value.$1),
          subtitle: Text(need.value.$2),
          value: _selectedNeeds.contains(need.key),
          onChanged: _disabled
              ? null
              : (value) => setState(() {
                  _dirty = true;
                  if (value == true) {
                    _selectedNeeds.add(need.key);
                  } else {
                    _selectedNeeds.remove(need.key);
                  }
                }),
        ),
      const SizedBox(height: 16),
      FilledButton(
        onPressed: _disabled ? null : () => _go(1),
        child: const Text('Next'),
      ),
      TextButton(
        onPressed: _disabled
            ? null
            : (widget.onboarding ? _cancel : () => _go(-1)),
        child: const Text('Back'),
      ),
    ],
  );
  Widget _features() => SectionCard(
    title: 'Accessibility features',
    children: [
      ..._featureControls(),
      const SizedBox(height: 16),
      const Text('These controls work independently of your selected needs.'),
      const SizedBox(height: 12),
      FilledButton(
        onPressed: _disabled ? null : () => _go(2),
        child: const Text('Next'),
      ),
      TextButton(
        onPressed: _disabled ? null : () => _go(0),
        child: const Text('Back'),
      ),
    ],
  );
  List<Widget> _savedAdditionalChoices() => [
    if (_basePreferences.enabledFeatures.isNotEmpty) ...[
      const SizedBox(height: 12),
      const Text('Additional saved choices'),
      for (final feature in _basePreferences.enabledFeatures)
        Text(_featureNames[feature]!),
      const Text(
        'These saved choices are not active in this app version. They will be preserved. No voice feature is enabled.',
      ),
    ],
  ];
  Widget _review() => SectionCard(
    title: 'Review and confirm',
    children: [
      const Text(
        'Accessibility needs',
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
      Text(
        _selectedNeeds.isEmpty
            ? 'None selected'
            : _needs.entries
                  .where((e) => _selectedNeeds.contains(e.key))
                  .map((e) => e.value.$1)
                  .join(', '),
      ),
      TextButton(
        onPressed: _disabled ? null : () => _go(0),
        child: const Text('Edit accessibility needs'),
      ),
      const SizedBox(height: 12),
      const Text(
        'Selected accessibility features',
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
      Text('Text size: ${(_scale * 100).round()}%'),
      Text('High contrast: ${_contrast ? 'On' : 'Off'}'),
      Text('Reduced motion: ${_motion ? 'On' : 'Off'}'),
      ..._savedAdditionalChoices(),
      TextButton(
        onPressed: _disabled ? null : () => _go(1),
        child: const Text('Edit accessibility features'),
      ),
      const SizedBox(height: 16),
      const Text(
        'Confirm to save these preferences. This is not a medical assessment or legal consent.',
      ),
      const SizedBox(height: 12),
      FilledButton(
        onPressed: _disabled ? null : _confirm,
        child: Text(_saving ? 'Saving preferences' : 'Confirm and save'),
      ),
      TextButton(
        onPressed: _disabled ? null : () => _go(1),
        child: const Text('Back'),
      ),
    ],
  );
  Widget _settings() => SectionCard(
    title: 'Accessibility',
    children: [
      const Text('Changes stay in this draft until you review and confirm.'),
      const SizedBox(height: 12),
      Text(
        _selectedNeeds.isEmpty
            ? 'Accessibility needs: None selected'
            : 'Accessibility needs: ${_needs.entries.where((e) => _selectedNeeds.contains(e.key)).map((e) => e.value.$1).join(', ')}',
      ),
      TextButton(
        onPressed: _disabled ? null : () => _go(0),
        child: const Text('Edit accessibility needs'),
      ),
      ..._featureControls(),
      ..._savedAdditionalChoices(),
      const SizedBox(height: 20),
      FilledButton(
        onPressed: _disabled ? null : () => _go(2),
        child: const Text('Review changes'),
      ),
    ],
  );
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.controller,
    builder: (context, _) => PopScope(
      canPop: !widget.active || (_step < 0 && !_disabled),
      onPopInvokedWithResult: (didPop, _) {
        if (didPop || !widget.active || _disabled) return;
        if (_step > 0) {
          _go(_step - 1);
        } else {
          _cancel();
        }
      },
      child: ListView(
        controller: _scroll,
        padding: const EdgeInsets.all(16),
        children: [
          if (_step >= 0) ...[
            Semantics(
              liveRegion: true,
              header: true,
              child: Text(
                'Step ${_step + 1} of 3',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            const SizedBox(height: 12),
          ],
          if (_message != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Semantics(liveRegion: true, child: Text(_message!)),
            ),
          if (widget.controller.error != null) ...[
            WorkspaceError(
              message: widget.controller.error!,
              onDismiss: widget.controller.clearError,
            ),
            TextButton(
              onPressed: _disabled ? null : _reload,
              child: const Text('Reload and discard draft'),
            ),
          ],
          if (_step == 0)
            _assessment()
          else if (_step == 1)
            _features()
          else if (_step == 2)
            _review()
          else
            _settings(),
          TextButton(
            onPressed: _disabled ? null : _cancel,
            child: const Text('Cancel'),
          ),
        ],
      ),
    ),
  );
}
