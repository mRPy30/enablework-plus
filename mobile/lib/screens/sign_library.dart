import 'dart:convert';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

class SignLibrary extends StatefulWidget {
  const SignLibrary({
    this.greetings = false,
    this.practice = false,
    this.lessonLabel,
    super.key,
  });
  final bool greetings, practice;
  final String? lessonLabel;
  @override
  State<SignLibrary> createState() => _SignLibraryState();
}

class _SignLibraryState extends State<SignLibrary> {
  late final catalog = rootBundle
      .loadString('assets/fsl/catalog.json')
      .then((s) => (jsonDecode(s) as List).cast<Map<String, dynamic>>());
  String query = '';
  @override
  Widget build(BuildContext context) {
    if (widget.lessonLabel case final label?) {
      return FutureBuilder<List<Map<String, dynamic>>>(
        future: catalog,
        builder: (_, snapshot) {
          final sign = snapshot.data
              ?.where((item) => item['label'] == label)
              .firstOrNull;
          if (sign != null) {
            return _Lesson(
              id: sign['id'],
              label: label,
              filipino: sign['filipino'],
              practice: false,
            );
          }
          return Scaffold(
            appBar: AppBar(title: Text(label)),
            body: Center(
              child: snapshot.connectionState == ConnectionState.done
                  ? const Text('This sign could not be loaded.')
                  : const CircularProgressIndicator(),
            ),
          );
        },
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.practice
              ? 'Practice a sign'
              : widget.greetings
              ? 'FSL greetings'
              : 'FSL dictionary',
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: TextField(
                decoration: const InputDecoration(
                  labelText: 'Find a sign',
                  hintText: 'Search in Filipino or English',
                  prefixIcon: Icon(Icons.search),
                ),
                onChanged: (v) =>
                    setState(() => query = v.trim().toLowerCase()),
              ),
            ),
            Expanded(
              child: FutureBuilder<List<Map<String, dynamic>>>(
                future: catalog,
                builder: (context, snapshot) {
                  if (snapshot.hasError)
                    return const Center(
                      child: Text('The sign library could not be loaded.'),
                    );
                  if (!snapshot.hasData)
                    return const Center(child: CircularProgressIndicator());
                  final signs = snapshot.requireData
                      .where(
                        (s) =>
                            (!widget.greetings ||
                                s['category'] == 'Greeting') &&
                            ((s['label'] as String).toLowerCase().contains(
                                  query,
                                ) ||
                                (s['filipino'] as String)
                                    .toLowerCase()
                                    .contains(query)),
                      )
                      .toList();
                  if (signs.isEmpty)
                    return const Center(
                      child: Text('No signs match this search.'),
                    );
                  return ListView.builder(
                    itemCount: signs.length,
                    itemBuilder: (context, i) {
                      final sign = signs[i];
                      return ListTile(
                        title: Text(sign['label']),
                        subtitle: Text(sign['filipino']),
                        trailing: const Icon(Icons.play_circle_outline),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute<void>(
                            builder: (_) => _Lesson(
                              id: sign['id'],
                              label: sign['label'],
                              filipino: sign['filipino'],
                              practice: widget.practice,
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Lesson extends StatefulWidget {
  const _Lesson({
    required this.id,
    required this.label,
    required this.filipino,
    required this.practice,
  });
  final String id, label, filipino;
  final bool practice;
  @override
  State<_Lesson> createState() => _LessonState();
}

class _LessonState extends State<_Lesson> with WidgetsBindingObserver {
  late final video = VideoPlayerController.asset('assets/fsl/${widget.id}.mp4');
  late final ready = video.initialize();
  CameraController? camera;
  int generation = 0;
  bool opening = false;
  String? message;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  Future<void> startCamera() async {
    if (opening || camera != null) return;
    final current = ++generation;
    setState(() {
      opening = true;
      message = null;
    });
    CameraController? pending;
    try {
      final cameras = await availableCameras();
      if (!mounted || current != generation) return;
      if (cameras.isEmpty) throw StateError('No camera');
      final selected = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );
      pending = CameraController(
        selected,
        ResolutionPreset.medium,
        enableAudio: false,
      );
      await pending.initialize();
      if (!mounted || current != generation) return;
      camera = pending;
      pending = null;
    } catch (_) {
      if (mounted && current == generation) message = 'Camera unavailable. Check camera permission or practice along with the video.';
    } finally {
      await pending?.dispose();
      if (mounted && current == generation) setState(() => opening = false);
    }
  }

  void stopCamera() {
    generation++;
    final previous = camera;
    camera = null;
    opening = false;
    previous?.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      video.pause();
      setState(stopCamera);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    stopCamera();
    video.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(widget.label)),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(widget.filipino, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          FutureBuilder<void>(
            future: ready,
            builder: (context, snap) {
              if (snap.hasError)
                return const Text('This video could not be played.');
              if (snap.connectionState != ConnectionState.done)
                return const Center(child: CircularProgressIndicator());
              return ValueListenableBuilder<VideoPlayerValue>(
                valueListenable: video,
                builder: (context, value, _) => Column(
                  children: [
                    AspectRatio(
                      aspectRatio: value.aspectRatio,
                      child: VideoPlayer(video),
                    ),
                    FilledButton.icon(
                      onPressed: () async {
                        if (value.isPlaying) {
                          await video.pause();
                          return;
                        }
                        if (value.isCompleted)
                          await video.seekTo(Duration.zero);
                        if (mounted) await video.play();
                      },
                      icon: Icon(
                        value.isPlaying ? Icons.pause : Icons.play_arrow,
                      ),
                      label: Text(
                        value.isPlaying
                            ? 'Pause'
                            : value.isCompleted
                            ? 'Replay sign'
                            : 'Play sign',
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          if (widget.practice) ...[
            const Text(
              'Watch the sign, then use your camera like a mirror. The preview is not recorded or scored.',
            ),
            if (camera != null)
              AspectRatio(
                aspectRatio: camera!.value.aspectRatio,
                child: CameraPreview(camera!),
              ),
            OutlinedButton.icon(
              onPressed: opening
                  ? null
                  : camera == null
                  ? startCamera
                  : () => setState(stopCamera),
              icon: const Icon(Icons.videocam_outlined),
              label: Text(
                camera == null ? 'Start camera preview' : 'Stop camera',
              ),
            ),
            if (message != null) Text(message!),
          ],
          const SizedBox(height: 16),
          const Text(
            'Video from FSL-105 v2 by Isaiah Jassen Tupal (2023). Converted to MP4 without audio. DOI 10.17632/48y2y99mb9.2. Creative Commons Attribution 4.0 (creativecommons.org/licenses/by/4.0/).',
          ),
        ],
      ),
    ),
  );
}
