import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

import 'sign_library.dart';

enum GuideSection {
  welcome(
    "Welcome",
    "Piliin ang tulong na gusto mong gamitin sa pagbukas ng app.",
    "Magpatuloy para makapasok sa iyong account.",
    "Hello",
  ),
  account(
    "Account",
    "Para mag-sign in, ilagay ang email at password mo.",
    "Kung bago ka, piliin ang paggawa ng account at sundin ang email confirmation. Kung nagre-reset ka, ilagay ang bagong password.",
    "Understand",
  ),
  home(
    "Home",
    "Pindutin ang Search jobs para maghanap ng trabaho.",
    "Sa Quick actions, mapupuntahan mo ang résumé, applications at accessibility settings.",
    "Hello",
  ),
  jobs(
    "Jobs",
    "I-type ang trabaho o skill sa search. Puwede ring pumili ng work arrangement.",
    "Pindutin ang View job para basahin ang detalye ng napiling trabaho.",
    "Understand",
  ),
  job(
    "Job details",
    "Basahin ang qualifications, required skills at workplace accessibility.",
    "Piliin ang Review application kung gusto mong ihanda ang application mo.",
    "Do not understand",
  ),
  fit(
    "Job fit",
    "Basahin ang summary at tingnan kung aling skills ang tugma sa trabaho.",
    "Kung may kulang sa profile, bumalik sa Profile at idagdag ang skills na mayroon ka.",
    "Understand",
  ),
  review(
    "Review application",
    "Tingnan kung tama ang trabaho at kumpanya. Piliin ang résumé na nais mong ipadala.",
    "Suriin ang napili bago kumpirmahin ang application.",
    "Correct",
  ),
  applications(
    "Applications",
    "Hanapin ang trabahong inapplyan mo at basahin ang status.",
    "Buksan ang application para makita ang detalye nito.",
    "Know",
  ),
  details(
    "Application details",
    "Tingnan ang trabaho, status at résumé na ginamit mo.",
    "Kung kailangan mo ng tulong, tingnan ang mga opsyon para sa application na ito.",
    "Do not understand",
  ),
  support(
    "Application support",
    "Tingnan kung may iskedyul ng interview.",
    "Basahin ang mga mensahe at ilagay ang tanong mo para sa administrator.",
    "Thank you",
  ),
  profile(
    "Profile",
    "Ilagay ang skills at karanasan mo.",
    "Pindutin ang Save profile para ma-save ang pagbabago. Sa Manage resumes, puwede kang magdagdag ng PDF.",
    "Correct",
  ),
  resumes(
    "Manage resumes",
    "Piliin ang Choose PDF and upload para magdagdag ng résumé.",
    "Kapag ready na ang file, piliin ang Make current o Scan this resume.",
    "Correct",
  ),
  builder(
    "Résumé builder",
    "Punan ang impormasyon at skills na gusto mong ipakita.",
    "Suriin ang nilalaman bago gumawa ng résumé.",
    "Correct",
  ),
  scan(
    "Résumé scan",
    "Basahin ang strengths at ang mga bahaging puwedeng dagdagan.",
    "Gamitin ang mga mungkahi para i-edit ang résumé mo.",
    "Understand",
  ),
  settings(
    "Accessibility",
    "Piliin ang mga suportang komportable kang gamitin.",
    "Subukan ang mga setting at i-save ang pinili mo. Puwede mo itong baguhin muli.",
    "Slow",
  ),
  notifications(
    "Notifications",
    "Tingnan ang mga update sa iyong applications.",
    "Piliin ang update para makita ang kaugnay na application.",
    "Know",
  ),
  signs(
    "Sign language support",
    "Buksan ang dictionary at maghanap ng sign sa Filipino o English.",
    "Piliin ang sign at pindutin ang Play sign. Sa practice, puwede mong gamitin ang camera bilang salamin.",
    "Slow",
  );

  const GuideSection(this.title, this.firstStep, this.nextStep, this.sign);
  final String title, firstStep, nextStep, sign;
}

class FslSectionGuide extends StatelessWidget {
  const FslSectionGuide(this.section, {super.key});
  final GuideSection section;

  @override
  Widget build(BuildContext context) => Align(
    alignment: AlignmentDirectional.centerStart,
    child: TextButton.icon(
      icon: const Icon(Icons.sign_language_outlined),
      label: const Text('FSL guide'),
      onPressed: () => showDialog<void>(
        context: context,
        builder: (dialog) => AlertDialog(
          scrollable: true,
          title: Text('FSL guide · ${section.title}'),
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (section == GuideSection.home || section == GuideSection.jobs)
                _SectionSigning(
                  asset: 'assets/guide/${section.name}-instructions.mp4',
                ),
              Text('1. ${section.firstStep}'),
              const SizedBox(height: 12),
              Text('2. ${section.nextStep}'),
              const SizedBox(height: 20),
              Text(
                'Kaugnay na FSL sign',
                style: Theme.of(dialog).textTheme.titleSmall,
              ),
              OutlinedButton.icon(
                icon: const Icon(Icons.play_circle_outline),
                label: Text(section.sign),
                onPressed: () => Navigator.of(dialog).push(
                  MaterialPageRoute<void>(
                    builder: (_) => SignLibrary(lessonLabel: section.sign),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialog),
              child: const Text('Close'),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Plays the offline signing and navigation prototype on request.
class _SectionSigning extends StatefulWidget {
  const _SectionSigning({required this.asset});
  final String asset;

  @override
  State<_SectionSigning> createState() => _SectionSigningState();
}

class _SectionSigningState extends State<_SectionSigning> {
  VideoPlayerController? player;
  late final Future<bool> available = initialize();

  Future<bool> initialize() async {
    final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
    if (!mounted || !manifest.listAssets().contains(widget.asset)) return false;
    final controller = VideoPlayerController.asset(widget.asset);
    player = controller;
    await controller.initialize();
    return true;
  }

  @override
  void dispose() {
    player?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<bool>(
    future: available,
    builder: (context, snapshot) {
      if (snapshot.hasError) return const Text('Hindi ma-play ang FSL video.');
      if (snapshot.data != true) return const SizedBox.shrink();
      final controller = player!;
      return ValueListenableBuilder<VideoPlayerValue>(
        valueListenable: controller,
        builder: (context, value, _) => Column(
          children: [
            const Text(
              'Prototype para sa review: FSL sign, kasunod ang visual na mga hakbang.',
            ),
            const SizedBox(height: 8),
            AspectRatio(
              aspectRatio: value.aspectRatio,
              child: VideoPlayer(controller),
            ),
            TextButton.icon(
              icon: Icon(value.isPlaying ? Icons.pause : Icons.sign_language),
              label: Text(
                value.isPlaying
                    ? 'Pause'
                    : value.isCompleted
                    ? 'Replay guide prototype'
                    : 'Play guide prototype',
              ),
              onPressed: () async {
                if (value.isPlaying) {
                  await controller.pause();
                } else {
                  if (value.isCompleted) await controller.seekTo(Duration.zero);
                  if (mounted) await controller.play();
                }
              },
            ),
            const SizedBox(height: 12),
          ],
        ),
      );
    },
  );
}
