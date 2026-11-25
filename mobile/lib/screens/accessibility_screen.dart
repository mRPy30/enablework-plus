import 'fsl_section_guide.dart';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'sign_library.dart';

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

/// Copyable communication prompts for sign-language users. Live camera
/// translation is intentionally not presented as operational yet.
class SignLanguageSupportScreen extends StatelessWidget {
  const SignLanguageSupportScreen({super.key});

  static const _phrases = <(String, String)>[
    ('Hello', 'Hello. Thank you for connecting with me.'),
    ('I need help', 'I need help with this step.'),
    ('Written communication', 'I prefer written communication, please.'),
    ('Please repeat', 'Please repeat that more slowly.'),
    ('Accessibility support', 'I need an accessibility accommodation.'),
  ];

  Future<void> _copy(BuildContext context, String phrase) async {
    await Clipboard.setData(ClipboardData(text: phrase));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Phrase copied to clipboard.')),
      );
    }
  }

  void _openLibrary(
    BuildContext context, {
    bool greetings = false,
    bool practice = false,
  }) {
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => SignLibrary(greetings: greetings, practice: practice),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      const CareerHeading('Sign language support'),
      const FslSectionGuide(GuideSection.signs),
      SectionCard(
        title: 'Filipino Sign Language',
        children: [
          ListTile(
            leading: const Icon(Icons.play_circle_outline),
            title: const Text('Watch greetings in FSL'),
            onTap: () => _openLibrary(context, greetings: true),
          ),
          ListTile(
            leading: const Icon(Icons.menu_book),
            title: const Text('Look up a sign'),
            onTap: () => _openLibrary(context),
          ),
          ListTile(
            leading: const Icon(Icons.videocam_outlined),
            title: const Text('Practice a sign on camera'),
            onTap: () => _openLibrary(context, practice: true),
          ),
        ],
      ),
      SectionCard(
        title: 'Communication phrases',
        children: [
          for (final (label, phrase) in _phrases)
            ListTile(
              contentPadding: EdgeInsets.zero,
              minVerticalPadding: 10,
              leading: const Icon(Icons.sign_language_outlined, size: 32),
              title: Text(label),
              subtitle: Text(phrase),
              trailing: IconButton(
                tooltip: 'Copy phrase',
                icon: const Icon(Icons.copy_outlined, size: 28),
                onPressed: () => _copy(context, phrase),
              ),
            ),
        ],
      ),
    ],
  );
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
  static const _needIcons = <String, IconData>{
    'visual': Icons.visibility_outlined,
    'mobility': Icons.accessible_forward,
    'hearing': Icons.hearing_outlined,
    'speech': Icons.record_voice_over_outlined,
    'intellectual': Icons.psychology_outlined,
    'learning': Icons.menu_book_outlined,
    'psychosocial': Icons.self_improvement_outlined,
  };
  final _scroll = ScrollController();
  late AccessibilityPreferences _basePreferences;
  late double _scale;
  late bool _contrast, _motion, _voiceFirst;
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
    _voiceFirst = p.enabledFeatures.contains('voice_guidance');
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
        enabledFeatures: [
          ..._basePreferences.enabledFeatures.where(
            (f) => f != 'voice_guidance',
          ),
          if (_voiceFirst) 'voice_guidance',
        ],
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
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android)
      SwitchListTile(
        title: const Text('Voice-first mode'),
        subtitle: const Text(
          'Hear navigation guidance and job search results. With TalkBack, use its usual gestures or choose Hear navigation help.',
        ),
        value: _voiceFirst,
        onChanged: _disabled
            ? null
            : (v) => setState(() {
                _dirty = true;
                _voiceFirst = v;
              }),
      ),
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
        Card(
          margin: const EdgeInsets.only(bottom: 8),
          color: _selectedNeeds.contains(need.key)
              ? Theme.of(context).colorScheme.primaryContainer
              : Theme.of(context).colorScheme.surface,
          child: CheckboxListTile(
            key: ValueKey('need_${need.key}'),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12),
            controlAffinity: ListTileControlAffinity.leading,
            secondary: Icon(_needIcons[need.key]),
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
      if (!kIsWeb &&
          defaultTargetPlatform == TargetPlatform.android &&
          _selectedNeeds.any(const {'visual', 'mobility', 'learning'}.contains))
        const ListTile(
          leading: Icon(Icons.mic),
          title: Text('Try voice search'),
          subtitle: Text(
            'In Jobs, tap the microphone and say a title, company or city. You can edit the words or type instead.',
          ),
        ),
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
    if (_basePreferences.enabledFeatures.any((f) => f != 'voice_guidance')) ...[
      const SizedBox(height: 12),
      const Text('Additional saved choices'),
      for (final feature in _basePreferences.enabledFeatures.where(
        (f) => f != 'voice_guidance',
      ))
        Text(_featureNames[feature]!),
      const Text(
        'Your choices are saved. On Android, tap the microphone in Jobs whenever you want to search by voice.',
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
      Text('Voice-first mode: ${_voiceFirst ? 'On' : 'Off'}'),
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
      child: Scrollbar(
        controller: _scroll,
        thumbVisibility: true,
        interactive: true,
        child: ListView(
          controller: _scroll,
          padding: const EdgeInsets.fromLTRB(16, 16, 24, 24),
          children: [
            if (widget.onboarding || _step >= 0)
              CareerHeading(
                widget.onboarding
                    ? 'Personalise your experience'
                    : 'Accessibility settings',
              ),
            const FslSectionGuide(GuideSection.settings),
            if (_step >= 0) ...[
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Semantics(
                  liveRegion: true,
                  header: true,
                  child: Text(
                    'Step ${_step + 1} of 3',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
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
    ),
  );
}
