import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:enablework_plus/main.dart';
import 'package:enablework_plus/models/seeker_workspace.dart';
import 'package:enablework_plus/screens/dashboard_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/workspace_fakes.dart';
import 'workspace_access_test.dart' show FakeSession;

SeekerWorkspace workspace({
  String name = 'UI Test Seeker',
  bool large = false,
  Map<String, int> counts = const {'under_review': 1},
}) => SeekerWorkspace(
  profile: SeekerProfile(
    userId: 'dummy-a',
    updatedAt: 'snapshot',
    fields: {
      'full_name': name,
      'headline': 'Office support trainee',
      'city': 'Quezon City',
    },
  ),
  applicationCounts: counts,
  resumes: [],
  preferences: AccessibilityPreferences(
    preferencesReviewed: true,
    textScale: large ? 2 : 1,
    reduceMotion: large,
    highContrast: large,
  ),
);

Future<void> render(
  WidgetTester t,
  FakeRepository repo, {
  GlobalKey? captureKey,
}) async {
  t.view.physicalSize = const Size(360, 800);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.resetPhysicalSize);
  addTearDown(t.view.resetDevicePixelRatio);
  await t.pumpWidget(
    RepaintBoundary(
      key: captureKey,
      child: MainApp(service: FakeSession(), repositoryBuilder: (_, _) => repo),
    ),
  );
  await t.pump();
}

Future<void> showLabel(WidgetTester t, String label) async {
  final target = find.text(label);
  if (target.evaluate().isEmpty) {
    await t.scrollUntilVisible(
      target,
      220,
      scrollable: find.byType(Scrollable).first,
    );
  }
  await Scrollable.ensureVisible(t.element(target.first), alignment: .1);
  await t.pumpAndSettle();
}

Future<void> tapLabel(WidgetTester t, String label) async {
  await showLabel(t, label);
  await t.tap(find.text(label).first);
  await t.pumpAndSettle();
}

void main() {
  testWidgets('top bar opens notifications, profile and display controls', (t) async {
    await render(t, FakeRepository()..value = workspace(large: true));
    await t.pumpAndSettle();
    await t.tap(find.byTooltip('Notifications'));
    await t.pumpAndSettle();
    expect(find.text('Notifications'), findsOneWidget);
    await t.tap(find.byTooltip('Open profile'));
    await t.pumpAndSettle();
    expect(t.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex, 3);
    await t.tap(find.text('Display and controls'));
    await t.pumpAndSettle();
    expect(find.text('Welcome to EnableWork+'), findsOneWidget);
  });
  for (final (action, destination) in [
    ('Complete profile', 3),
    ('Find jobs', 1),
    ('My applications', 2),
    ('Accessibility settings', 4),
    ('See all jobs', 1),
    ('See all applications', 2),
  ]) {
    testWidgets('Authenticated Home opens $action', (t) async {
      await render(t, FakeRepository()..value = workspace());
      await t.pumpAndSettle();
      await tapLabel(t, action);
      expect(
        t.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
        destination,
      );
    });
  }
  testWidgets(
    'Authenticated career tabs offer no preview or submission actions',
    (t) async {
      await render(t, FakeRepository()..value = workspace(large: true));
      await t.pumpAndSettle();
      await tapLabel(t, 'Find jobs');
      expect(find.text('Listings currently unavailable'), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
      expect(find.text('Work arrangement'), findsNothing);
      expect(find.text('View job'), findsNothing);
      expect(find.text('Save application'), findsNothing);
      expect(find.text('Try again'), findsNothing);
      await expectLater(t, meetsGuideline(androidTapTargetGuideline));
      expect(t.takeException(), isNull);

      await t.tap(find.byIcon(Icons.assignment_outlined).last);
      await t.pumpAndSettle();
      expect(find.text('Application history unavailable'), findsOneWidget);
      expect(find.text('No applications yet'), findsNothing);
      expect(find.text('View application'), findsNothing);
      expect(find.text('Save application'), findsNothing);
      expect(find.textContaining('Sample data'), findsNothing);
      expect(find.text('Try again'), findsNothing);
      await expectLater(t, meetsGuideline(androidTapTargetGuideline));
      expect(t.takeException(), isNull);
    },
  );
  testWidgets('Authenticated resume shortcut opens the actual PDF manager', (
    t,
  ) async {
    await render(t, FakeRepository()..value = workspace());
    await t.pumpAndSettle();
    await tapLabel(t, 'Manage resumes');
    expect(find.text('Choose PDF and upload'), findsOneWidget);
    expect(find.text('Add sample resume'), findsNothing);
  });
  testWidgets('Loading and failed workspace never imply zero applications', (
    t,
  ) async {
    final repo = FakeRepository()..pendingLoad = Completer<SeekerWorkspace>();
    await render(t, repo);
    expect(find.byType(DashboardScreen), findsNothing);
    repo.pendingLoad!.completeError(
      const WorkspaceFailure('Connection unavailable.'),
    );
    await t.pumpAndSettle();
    expect(find.text('Try again'), findsOneWidget);
    expect(find.text('0 total applications'), findsNothing);
    repo.pendingLoad = null;
    repo.value = workspace(name: '', counts: {});
    await t.tap(find.text('Try again'));
    await t.pumpAndSettle();
    expect(find.text('Welcome back'), findsOneWidget);
    await showLabel(t, '0 total applications');
    expect(find.text('0 total applications'), findsOneWidget);
  });
  testWidgets(
    'Protected Home reflows with seeker text size, contrast and reduced motion',
    (t) async {
      await render(t, FakeRepository()..value = workspace(large: true));
      await t.pumpAndSettle();
      final ctx = t.element(find.byType(DashboardScreen));
      expect(MediaQuery.textScalerOf(ctx).scale(16), 32);
      expect(MediaQuery.disableAnimationsOf(ctx), isTrue);
      for (final label in [
        'Complete profile',
        'Accessibility settings',
        'Application overview',
        'See all jobs',
      ]) {
        await showLabel(t, label);
        expect(t.takeException(), isNull);
        await expectLater(t, meetsGuideline(androidTapTargetGuideline));
      }
    },
  );
  testWidgets(
    'main.dart Home uses the loaded seeker, counts and truthful job availability',
    (t) async {
      const folder = String.fromEnvironment('AUTH_HOME_CAPTURE_DIR');
      const fonts = String.fromEnvironment('AUTH_HOME_FONT_DIR');
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
      await render(t, FakeRepository()..value = workspace(), captureKey: key);
      await t.pumpAndSettle();
      Future<void> capture(String name) async {
        if (folder.isEmpty) return;
        final render =
            key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        await t.runAsync(() async {
          final image = await render.toImage(pixelRatio: 2);
          try {
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            await Directory(folder).create(recursive: true);
            await File('$folder/$name.png')
                .writeAsBytes(bytes!.buffer.asUint8List());
          } finally {
            image.dispose();
          }
        });
      }

      expect(find.text('Welcome, UI Test Seeker'), findsOneWidget);
      expect(find.text('Quezon City'), findsOneWidget);
      expect(find.text('50% complete'), findsOneWidget);
      expect(find.byIcon(Icons.notifications_none_outlined), findsNothing);
      expect(find.textContaining('Sample data'), findsNothing);
      await capture('authenticated-home');
      await showLabel(t, 'Under review: 1');
      expect(find.text('1 total application'), findsOneWidget);
      await showLabel(t, 'See all jobs');
      expect(
        find.text(
          'Explore openings and compare work arrangements, skills and accessibility details.',
        ),
        findsOneWidget,
      );
      expect(find.text('View job details'), findsNothing);
      await capture('authenticated-home-activity');
      await tapLabel(t, 'See all jobs');
      expect(find.text('Listings currently unavailable'), findsOneWidget);
      await capture('authenticated-jobs');
      await t.tap(find.text('Applications').last);
      await t.pumpAndSettle();
      expect(find.text('Application history unavailable'), findsOneWidget);
      await capture('authenticated-applications');
    },
  );
}
