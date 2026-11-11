import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:enablework_plus/models/seeker_workspace.dart';
import 'package:enablework_plus/screens/seeker_home.dart';

import 'support/workspace_fakes.dart';

// Optional source-widget captures with synthetic data. No production preview/auth bypass route.
void main() {
  testWidgets(
    'render each protected-workspace screen with synthetic fixtures',
    (tester) async {
      const output = String.fromEnvironment('PHASE2_PREVIEW_DIR');
      const fonts = String.fromEnvironment('PHASE2_FONT_DIR');
      if (fonts.isNotEmpty) {
        await tester.runAsync(() async {
          final roboto = FontLoader('Roboto')
            ..addFont(
              File('$fonts/roboto-regular.ttf')
                  .readAsBytes()
                  .then(ByteData.sublistView),
            )
            ..addFont(
              File('$fonts/roboto-bold.ttf')
                  .readAsBytes()
                  .then(ByteData.sublistView),
            );
          await roboto.load();
          await (FontLoader('MaterialIcons')..addFont(
                File('$fonts/materialicons-regular.otf')
                    .readAsBytes()
                    .then(ByteData.sublistView),
              ))
              .load();
        });
      }
      tester.view.physicalSize = const Size(430, 930);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final boundary = GlobalKey();
      final repo = FakeRepository()
        ..value = dummyWorkspace(
          resumes: [
            const ResumeRecord(
              id: 'dummy-pdf',
              title: 'Customer service resume',
              status: ResumeStatus.ready,
              isCurrent: true,
              sizeBytes: 24000,
            ),
            const ResumeRecord(
              id: 'dummy-pending',
              title: 'New resume version',
              status: ResumeStatus.pending,
            ),
          ],
        );
      await tester.pumpWidget(
        RepaintBoundary(
          key: boundary,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: ThemeData(
              useMaterial3: true,
              fontFamily: 'Roboto',
              colorScheme: ColorScheme.fromSeed(
                seedColor: const Color(0xff00695c),
              ),
            ),
            home: Scaffold(
              appBar: AppBar(title: const Text('EnableWork+')),
              body: SafeArea(
                child: SeekerHome(
                  repository: repo,
                  picker: FakePicker(null),
                  onPreferences: (_) {},
                  onAccessLost: () {},
                  onSignOut: () async {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      const names = [
        'dashboard',
        'jobs',
        'applications',
        'profile',
        'accessibility',
      ];
      for (var index = 0; index < names.length; index++) {
        await tester.tap(find.byType(NavigationDestination).at(index));
        await tester.pumpAndSettle();
        expect(tester.takeException(), null);
        if (output.isNotEmpty) {
          final render =
              boundary.currentContext!.findRenderObject()!
                  as RenderRepaintBoundary;
          await tester.runAsync(() async {
            final image = await render.toImage(pixelRatio: 2);
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            await Directory(output).create(recursive: true);
            await File('$output/phase-2-${names[index]}.png')
                .writeAsBytes(bytes!.buffer.asUint8List());
            image.dispose();
          });
        }
      }
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
