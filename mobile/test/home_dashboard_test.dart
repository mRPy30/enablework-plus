import 'dart:io';
import 'dart:ui' as ui;

import 'package:enablework_plus/demo/demo_workspace.dart';
import 'package:enablework_plus/main_demo.dart';
import 'package:enablework_plus/models/career_preview.dart';
import 'package:enablework_plus/screens/dashboard_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> reveal(WidgetTester t, Finder target) async {
  if (target.evaluate().isEmpty) {
    await t.scrollUntilVisible(
      target,
      260,
      scrollable: find.byType(Scrollable).first,
    );
  }
  await Scrollable.ensureVisible(t.element(target.first), alignment: .18);
  await t.pumpAndSettle();
}

Future<void> enterDemo(
  WidgetTester t, {
  GlobalKey? boundary,
  double scale = 1,
  double width = 400,
}) async {
  t.view.physicalSize = Size(width, 860);
  t.view.devicePixelRatio = 1;
  t.platformDispatcher.textScaleFactorTestValue = scale;
  addTearDown(t.view.resetPhysicalSize);
  addTearDown(t.view.resetDevicePixelRatio);
  addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
  await t.pumpWidget(RepaintBoundary(key: boundary, child: const ClientDemo()));
  await t.pumpAndSettle();
  final enter = find.text('Open seeker demo');
  await reveal(t, enter);
  await t.tap(enter);
  await t.pumpAndSettle();
}

void main() {
  for (final (label, tab) in [
    ('Find jobs', 1),
    ('My applications', 2),
    ('Accessibility settings', 4),
    ('See all jobs', 1),
    ('See all applications', 2),
  ]) {
    testWidgets('Home shortcut "$label" opens its existing tab', (t) async {
      await enterDemo(t);
      final action = find.text(label);
      await reveal(t, action);
      await t.tap(action);
      await t.pumpAndSettle();
      expect(
        t.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
        tab,
      );
    });
  }

  testWidgets(
    'Home resume and preview shortcuts open details and return to Home',
    (t) async {
      await enterDemo(t);
      final resumes = find.text('Manage resumes');
      await reveal(t, resumes);
      await t.tap(resumes);
      await t.pumpAndSettle();
      expect(find.text('Demo resumes'), findsOneWidget);
      await t.tap(find.byType(BackButton));
      await t.pumpAndSettle();
      final details = find.text('View job details');
      await reveal(t, details);
      await t.tap(details.first);
      await t.pumpAndSettle();
      expect(find.text('Catalog assistant'), findsOneWidget);
      expect(find.text('Workplace accessibility'), findsOneWidget);
      await t.tap(find.byType(BackButton));
      await t.pumpAndSettle();
      expect(
        t.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
        0,
      );
    },
  );

  testWidgets(
    'readiness and statuses reflect the workspace; preview handles missing information',
    (t) async {
      final session = DemoWorkspace();
      final job = session.jobs.first;
      final withoutDetails = JobListing(
        job.id,
        job.title,
        job.company,
        job.city,
        job.arrangement,
        job.employment,
        job.description,
        [],
      );
      Future<void> show(List<JobListing>? jobs) async {
        final data = await session.load();
        await t.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: DashboardScreen(
                key: UniqueKey(),
                data: data,
                demoJobs: jobs,
                openTab: (_) {},
                openResumes: () {},
                openJob: (_) {},
              ),
            ),
          ),
        );
        await t.pumpAndSettle();
      }

      await show([]);
      expect(find.text('67% complete'), findsOneWidget);
      expect(find.text('DS'), findsOneWidget);
      await reveal(t, find.text('No demo jobs available.'));
      await reveal(t, find.text('0 total applications'));
      expect(
        find.text('Save a demo application to see its status here.'),
        findsOneWidget,
      );
      session.savePreview(job, 'sample');
      await show([withoutDetails]);
      await reveal(t, find.text('Workplace accessibility: Not provided'));
      expect(find.text('DEMO DATA'), findsOneWidget);
      await reveal(t, find.text('Submitted: 1'));
      expect(find.text('1 total application'), findsOneWidget);
      await show(null);
      await reveal(t, find.text('Live job listings are not connected yet.'));
      expect(find.text('DEMO DATA'), findsNothing);
    },
  );

  testWidgets(
    '360-wide Home reflows at double text size with accessible actions',
    (t) async {
      await enterDemo(t, width: 360, scale: 2);
      expect(find.text('Welcome, Demo Seeker'), findsOneWidget);
      for (final label in [
        'Profile readiness',
        'Quick actions',
        'Accessibility settings',
        'Job opportunities',
        'See all applications',
      ]) {
        await reveal(t, find.text(label));
        expect(t.takeException(), isNull);
      }
      await expectLater(t, meetsGuideline(androidTapTargetGuideline));
    },
  );

  testWidgets('Home renders branded demo previews using the existing jobs', (
    t,
  ) async {
    const out = String.fromEnvironment('DASHBOARD_CAPTURE_DIR');
    const fonts = String.fromEnvironment('DASHBOARD_FONT_DIR');
    if (fonts.isNotEmpty) {
      await t.runAsync(() async {
        for (final (family, files) in [
          ('Roboto', ['roboto-regular.ttf', 'roboto-bold.ttf']),
          ('MaterialIcons', ['materialicons-regular.otf']),
        ]) {
          final loader = FontLoader(family);
          for (final file in files) {
            loader.addFont(
              File('$fonts/$file').readAsBytes().then(ByteData.sublistView),
            );
          }
          await loader.load();
        }
      });
    }
    final key = GlobalKey();
    await enterDemo(t, boundary: key);
    Future<void> capture(String name) async {
      if (out.isEmpty) return;
      final render =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      await t.runAsync(() async {
        final image = await render.toImage(pixelRatio: 2);
        try {
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          await Directory(out).create(recursive: true);
          await File('$out/$name.png')
              .writeAsBytes(bytes!.buffer.asUint8List());
        } finally {
          image.dispose();
        }
      });
    }

    await capture('home');
    await reveal(t, find.text('Job opportunities'));
    expect(find.text('Catalog assistant'), findsOneWidget);
    expect(find.text('Paper Lantern Studio · Quezon City'), findsOneWidget);
    expect(find.text('Part-time · Hybrid'), findsOneWidget);
    expect(find.text('DEMO DATA'), findsWidgets);
    await capture('opportunities');
    await reveal(t, find.text('See all applications'));
    expect(find.text('Records assistant'), findsNothing);
    expect(find.text('0 total applications'), findsOneWidget);
    await capture('applications');
  });
}
