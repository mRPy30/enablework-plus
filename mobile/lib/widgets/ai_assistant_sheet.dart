import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AiAssistantSheet extends StatefulWidget {
  const AiAssistantSheet({
    required this.onScanResume,
    required this.onFindMatch,
    required this.onBuildResume,
    required this.onAccessibility,
    required this.onSignLanguage,
    required this.matchingAvailable,
    super.key,
  });

  final VoidCallback onScanResume;
  final VoidCallback onFindMatch;
  final VoidCallback onBuildResume;
  final VoidCallback onAccessibility;
  final VoidCallback onSignLanguage;
  final bool matchingAvailable;

  @override
  State<AiAssistantSheet> createState() => _AiAssistantSheetState();
}

class _AiAssistantSheetState extends State<AiAssistantSheet> {
  static const voice = MethodChannel('enablework_plus/voice_search');
  static const tts = MethodChannel('enablework_plus/tts');
  final input = TextEditingController();
  final turns = <(String, String)>[];
  String? notice;
  VoidCallback? next;
  String? action;
  bool listening = false;
  bool get android =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  Future<void> stop() async {
    if (!android) return;
    try {
      await tts.invokeMethod<void>('stop');
    } on PlatformException {
      return;
    } on MissingPluginException {
      return;
    }
  }

  @override
  void dispose() {
    stop();
    input.dispose();
    super.dispose();
  }

  Future<void> listen() async {
    if (listening) return;
    setState(() {
      listening = true;
      notice = null;
    });
    try {
      await stop();
      if (!mounted) return;
      final words = await voice.invokeMethod<String>('listen', {
        'prompt': 'Ask EnableWork+ about jobs, resumes or accessibility',
      });
      if (mounted && words != null && words.trim().isNotEmpty) {
        await respond(words, spoken: true);
      }
    } on PlatformException {
      if (mounted)
        setState(
          () =>
              notice = 'Voice input is unavailable. Type your question below.',
        );
    } on MissingPluginException {
      if (mounted)
        setState(
          () =>
              notice = 'Voice input is unavailable. Type your question below.',
        );
    } finally {
      if (mounted) setState(() => listening = false);
    }
  }

  Future<void> respond(String text, {bool spoken = false}) async {
    final words = text.trim();
    if (words.isEmpty) return;
    final q = words
        .toLowerCase()
        .replaceAll('é', 'e')
        .replaceAll(RegExp(r'[^a-z0-9ñ ]'), '')
        .trim();
    bool has(List<String> terms) => terms.any(q.contains);
    if (next != null &&
        [
          'yes',
          'oo',
          'sige',
          'open',
          'buksan',
          'buksan mo',
          'open it',
          'go',
        ].contains(q)) {
      next!();
      return;
    }
    if (next != null &&
        [
          'paano',
          'paano yun',
          'paano yan',
          'how',
          'how do i do that',
          'what next',
        ].contains(q)) {
      final followUp =
          'Pindutin ang "${action!}" sa ibaba o sabihin ang "sige" para buksan ito.';
      input.clear();
      setState(() {
        turns.add((words, followUp));
        notice = null;
      });
      if (spoken) await speak(followUp);
      return;
    }
    String reply;
    VoidCallback? target;
    String? label;
    if (has(['sign language', 'fsl', 'senyas', 'senya'])) {
      reply = 'May video lessons at sign dictionary. Gusto mong buksan ang Filipino Sign Language resources?';
      target = widget.onSignLanguage;
      label = 'Open FSL resources';
    } else if (has(['build', 'gawa', 'create']) &&
        has(['resume', 'résumé', 'cv'])) {
      reply = 'Sa Manage resumes, piliin ang resume builder para gumawa ng résumé. Buksan natin?';
      target = widget.onBuildResume;
      label = 'Open resume builder tools';
    } else if (has(['resume', 'résumé', 'scan', 'cv'])) {
      reply = 'Sa Manage resumes, pumili ng résumé at pindutin ang Scan para makita ang feedback. Buksan natin?';
      target = widget.onScanResume;
      label = 'Open resumes';
    } else if (has([
      'trabaho',
      'hanap',
      'job',
      'match',
      'fit',
      'apply',
      'aplay',
    ])) {
      reply = widget.matchingAvailable
          ? 'Sa Jobs, pumili ng posting at pindutin ang Check job fit para ikumpara ang skills mo sa requirements. Buksan natin ang Jobs?'
          : 'Makakapag-browse ka ng openings sa Jobs. Buksan natin?';
      target = widget.onFindMatch;
      label = 'Open Jobs';
    } else if (has([
      'access',
      'settings',
      'laki',
      'text',
      'contrast',
      'motion',
      'basa',
      'font',
    ])) {
      reply = 'Sa Settings, puwedeng baguhin ang laki ng text, contrast at motion. Buksan natin?';
      target = widget.onAccessibility;
      label = 'Open accessibility settings';
    } else if (['no', 'hindi', 'wag', 'huwag', 'cancel'].contains(q)) {
      reply = 'Sige. Ano pa ang gusto mong malaman?';
    } else {
      reply = 'Matutulungan kita sa paghahanap ng trabaho, résumé, sign language at accessibility. Halimbawa, itanong ang “Paano mag-scan ng resume?”';
    }
    input.clear();
    setState(() {
      turns.add((words, reply));
      next = target;
      action = label;
      notice = null;
    });
    if (spoken) await speak(reply);
  }

  Future<void> speak(String reply) async {
    try {
      await tts.invokeMethod<void>('speak', {
        'text': reply,
        'language': 'fil-PH',
      });
    } on PlatformException {
      if (mounted)
        setState(
          () => notice = 'Spoken reply unavailable. Read the reply above.',
        );
    } on MissingPluginException {
      if (mounted)
        setState(
          () => notice = 'Spoken reply unavailable. Read the reply above.',
        );
    }
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        children: [
          Text(
            'EnableWork+ Assistant',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const Text(
            'Ask about jobs, resumes or accessibility in Filipino or English.',
          ),
          if (android)
            FilledButton.icon(
              onPressed: listening ? null : listen,
              icon: const Icon(Icons.mic),
              label: const Text('Talk to Assistant'),
            ),
          TextField(
            controller: input,
            textInputAction: TextInputAction.send,
            decoration: InputDecoration(
              labelText: 'Type a question',
              suffixIcon: IconButton(
                tooltip: 'Send question',
                icon: const Icon(Icons.send),
                onPressed: () => respond(input.text),
              ),
            ),
            onSubmitted: (s) => respond(s),
          ),
          if (notice != null) Semantics(liveRegion: true, child: Text(notice!)),
          if (turns.isNotEmpty) ...[
            Text(turns.last.$1, style: Theme.of(context).textTheme.labelLarge),
            Semantics(liveRegion: true, child: Text(turns.last.$2)),
            if (next != null)
              OutlinedButton(onPressed: next, child: Text(action!)),
            if (turns.length > 1)
              ExpansionTile(
                title: const Text('Earlier messages'),
                children: [
                  for (final t in turns.take(turns.length - 1))
                    ListTile(title: Text(t.$1), subtitle: Text(t.$2)),
                ],
              ),
          ],
          _ActionTile(
            icon: Icons.document_scanner_outlined,
            title: 'Scan my resume',
            subtitle: 'Review skills, structure, and accessibility notes',
            onTap: widget.onScanResume,
          ),
          _ActionTile(
            icon: Icons.work_outline,
            title: 'Find my job fit',
            subtitle: widget.matchingAvailable
                ? 'Compare a job with your profile and resume'
                : 'Available after the matching service is connected',
            onTap: widget.onFindMatch,
            enabled: widget.matchingAvailable,
          ),
          _ActionTile(
            icon: Icons.edit_note,
            title: 'Build an accessible resume',
            subtitle: 'Create a structured resume with accessibility in mind',
            onTap: widget.onBuildResume,
          ),
          _ActionTile(
            icon: Icons.accessibility_new,
            title: 'Update accessibility preferences',
            subtitle: 'Adjust the experience to fit your access needs',
            onTap: widget.onAccessibility,
          ),
          _ActionTile(
            icon: Icons.sign_language_outlined,
            title: 'Sign language support',
            subtitle: 'Watch FSL signs, practice, or copy a phrase',
            onTap: widget.onSignLanguage,
          ),
        ],
      ),
    ),
  );
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.enabled = true,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: const EdgeInsets.symmetric(vertical: 4),
    enabled: enabled,
    leading: Icon(icon),
    title: Text(title),
    subtitle: Text(subtitle),
    trailing: const Icon(Icons.chevron_right),
    onTap: enabled ? onTap : null,
  );
}
