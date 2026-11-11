import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:enablework_plus/main.dart';
import 'package:enablework_plus/models/account_profile.dart';
import 'package:enablework_plus/models/seeker_workspace.dart';
import 'package:enablework_plus/screens/accessibility_screen.dart';
import 'package:enablework_plus/state/seeker_controller.dart';

import 'support/workspace_fakes.dart';
import 'workspace_access_test.dart' show FakeSession, MutableSession;

Future<void> tapLabel(WidgetTester tester, String label) async {
  final target = find.text(label);
  final scroll = find.byType(Scrollable).first;
  if (target.evaluate().isEmpty) {
    await tester.scrollUntilVisible(target, 240, scrollable: scroll);
  }
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  if (target.hitTestable().evaluate().isEmpty) {
    final delta = tester.getCenter(target).dy < tester.getCenter(scroll).dy
        ? -200.0
        : 200.0;
    await tester.scrollUntilVisible(
      target.hitTestable(),
      delta,
      scrollable: scroll,
    );
  }
  await tester.tap(target);
  await tester.pumpAndSettle();
}

Future<SeekerController> showFlow(
  WidgetTester tester,
  FakeRepository repo, {
  bool onboarding = true,
}) async {
  final controller = SeekerController(
    repo,
    onPreferences: (_) {},
    onAccessLost: () {},
  );
  await controller.load();
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: AccessibilityScreen(
          controller: controller,
          onboarding: onboarding,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  addTearDown(controller.dispose);
  return controller;
}

FakeRepository unreviewed() =>
    FakeRepository()
      ..value = dummyWorkspace(preferences: const AccessibilityPreferences());

class AdministratorSession extends FakeSession {
  @override
  Future<AccountProfile> requireAccess() async =>
      const AccountProfile(AppRole.systemAdministrator);
}

class StalePreferences extends FakeRepository {
  @override
  Future<void> savePreferences(AccessibilityPreferences preferences) async {
    throw const WorkspaceFailure(
      'Your accessibility preferences changed elsewhere. Reload before saving.',
    );
  }
}

void main() {
  testWidgets(
    'seven accessible categories support multiple choices and retained drafts',
    (tester) async {
      final repo = unreviewed();
      await showFlow(tester, repo);
      expect(find.byType(CheckboxListTile), findsNWidgets(7));
      for (final label in [
        'Visual',
        'Mobility',
        'Hearing',
        'Speech',
        'Intellectual',
        'Learning',
        'Psychosocial',
      ]) {
        expect(find.text(label), findsOneWidget);
      }
      await tapLabel(tester, 'Visual');
      await tapLabel(tester, 'Hearing');
      await tester.ensureVisible(find.byKey(const ValueKey('need_visual')));
      expect(
        tester.getSemantics(find.byKey(const ValueKey('need_visual'))),
        isSemantics(hasCheckedState: true, isChecked: true),
      );
      await tapLabel(tester, 'Next');
      expect(find.byType(SwitchListTile), findsNWidgets(2));
      expect(
        tester
            .widget<SwitchListTile>(
              find.widgetWithText(SwitchListTile, 'High contrast'),
            )
            .value,
        false,
      );
      expect(repo.value.preferences.enabledFeatures, isEmpty);
      await tapLabel(tester, 'Back');
      expect(
        tester
            .widget<CheckboxListTile>(find.byKey(const ValueKey('need_visual')))
            .value,
        true,
      );
      expect(
        tester
            .widget<CheckboxListTile>(
              find.byKey(const ValueKey('need_hearing')),
            )
            .value,
        true,
      );
      expect(repo.preferenceSaves, 0);
      expect(repo.value.preferences.accessibilityNeeds, isEmpty);
    },
  );
  testWidgets('empty assessment reaches review and confirms explicitly', (
    tester,
  ) async {
    final repo = unreviewed();
    await showFlow(tester, repo);
    await tapLabel(tester, 'Next');
    await tapLabel(tester, 'Next');
    expect(find.text('None selected'), findsOneWidget);
    expect(repo.value.preferences.preferencesReviewed, false);
    await tapLabel(tester, 'Confirm and save');
    expect(repo.preferenceSaves, 1);
    expect(repo.value.preferences.preferencesReviewed, true);
    expect(repo.value.preferences.accessibilityNeeds, isEmpty);
  });
  testWidgets(
    'existing feature controls load and remain independent of needs',
    (tester) async {
      final repo = FakeRepository()
        ..value = dummyWorkspace(
          preferences: const AccessibilityPreferences(
            textScale: 1.5,
            highContrast: true,
            reduceMotion: true,
            accessibilityNeeds: ['mobility'],
          ),
        );
      await showFlow(tester, repo);
      await tapLabel(tester, 'Next');
      expect(tester.widget<Slider>(find.byType(Slider)).value, 1.5);
      expect(
        tester
            .widget<SwitchListTile>(
              find.widgetWithText(SwitchListTile, 'High contrast'),
            )
            .value,
        true,
      );
      expect(
        find.widgetWithText(SwitchListTile, 'Voice guidance'),
        findsNothing,
      );
      expect(
        find.widgetWithText(SwitchListTile, 'Text-to-speech'),
        findsNothing,
      );
      expect(find.widgetWithText(SwitchListTile, 'Voice search'), findsNothing);
      await tapLabel(tester, 'High contrast');
      await tapLabel(tester, 'Next');
      expect(find.text('Mobility'), findsOneWidget);
      expect(find.text('High contrast: Off'), findsOneWidget);
      expect(find.text('Reduced motion: On'), findsOneWidget);
      expect(find.text('Text size: 150%'), findsOneWidget);
      await tapLabel(tester, 'Confirm and save');
      expect(repo.value.preferences.highContrast, false);
      expect(repo.value.preferences.textScale, 1.5);
      expect(repo.value.preferences.accessibilityNeeds, ['mobility']);
      expect(repo.value.preferences.enabledFeatures, isEmpty);
    },
  );
  testWidgets(
    'review edit actions return to their step and retain selections',
    (tester) async {
      await showFlow(tester, unreviewed());
      await tapLabel(tester, 'Visual');
      await tapLabel(tester, 'Next');
      await tapLabel(tester, 'High contrast');
      await tapLabel(tester, 'Next');
      await tapLabel(tester, 'Edit accessibility needs');
      expect(find.text('Accessibility assessment'), findsOneWidget);
      expect(
        tester
            .widget<CheckboxListTile>(find.byKey(const ValueKey('need_visual')))
            .value,
        true,
      );
      await tapLabel(tester, 'Next');
      await tapLabel(tester, 'Next');
      await tapLabel(tester, 'Edit accessibility features');
      expect(find.text('Accessibility features'), findsOneWidget);
      expect(
        tester
            .widget<SwitchListTile>(
              find.widgetWithText(SwitchListTile, 'High contrast'),
            )
            .value,
        true,
      );
    },
  );
  testWidgets(
    'Settings cancel discards draft without saving or changing review state',
    (tester) async {
      final repo = FakeRepository();
      await showFlow(tester, repo, onboarding: false);
      await tapLabel(tester, 'High contrast');
      await tapLabel(tester, 'Edit accessibility needs');
      await tapLabel(tester, 'Visual');
      await tapLabel(tester, 'Cancel');
      expect(repo.preferenceSaves, 0);
      expect(repo.value.preferences.highContrast, false);
      expect(repo.value.preferences.accessibilityNeeds, isEmpty);
      expect(repo.value.preferences.preferencesReviewed, true);
      expect(find.text('Review changes'), findsOneWidget);
    },
  );
  testWidgets(
    'opening and editing Settings does not mark an unreviewed record reviewed',
    (tester) async {
      final repo = unreviewed();
      await showFlow(tester, repo, onboarding: false);
      await tapLabel(tester, 'High contrast');
      await tapLabel(tester, 'Review changes');
      expect(repo.value.preferences.preferencesReviewed, false);
      expect(repo.preferenceSaves, 0);
    },
  );
  testWidgets('failed save retains draft and does not falsely confirm', (
    tester,
  ) async {
    final repo = unreviewed();
    await showFlow(tester, repo);
    await tapLabel(tester, 'Visual');
    await tapLabel(tester, 'Next');
    await tapLabel(tester, 'Next');
    repo.fail = const WorkspaceFailure('Connection unavailable.');
    await tapLabel(tester, 'Confirm and save');
    expect(repo.value.preferences.preferencesReviewed, false);
    expect(repo.preferenceSaves, 0);
    expect(find.text('Connection unavailable.'), findsOneWidget);
    expect(find.text('Review and confirm'), findsOneWidget);
    expect(find.text('Visual'), findsOneWidget);
  });
  testWidgets(
    'conflict never retries overwrite; explicit reload discards draft',
    (tester) async {
      final repo = StalePreferences()
        ..value = dummyWorkspace(preferences: const AccessibilityPreferences());
      await showFlow(tester, repo);
      await tapLabel(tester, 'Visual');
      await tapLabel(tester, 'Next');
      await tapLabel(tester, 'Next');
      await tapLabel(tester, 'Confirm and save');
      expect(repo.preferenceSaves, 0);
      expect(repo.value.preferences.preferencesReviewed, false);
      expect(find.textContaining('changed elsewhere'), findsOneWidget);
      await tapLabel(tester, 'Reload and discard draft');
      expect(
        tester
            .widget<CheckboxListTile>(find.byKey(const ValueKey('need_visual')))
            .value,
        false,
      );
    },
  );
  testWidgets('repeated confirmation is disabled while save is pending', (
    tester,
  ) async {
    final repo = unreviewed()..preferenceSaveGate = Completer<void>();
    await showFlow(tester, repo);
    await tapLabel(tester, 'Next');
    await tapLabel(tester, 'Next');
    await tester.ensureVisible(find.text('Confirm and save'));
    await tester.tap(find.text('Confirm and save'));
    await tester.pump();
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Saving preferences'),
          )
          .onPressed,
      isNull,
    );
    repo.preferenceSaveGate!.complete();
    await tester.pumpAndSettle();
    expect(repo.preferenceSaves, 1);
  });
  testWidgets(
    'saved unavailable choices are preserved but not advertised as operational controls',
    (tester) async {
      final repo = FakeRepository()
        ..value = dummyWorkspace(
          preferences: const AccessibilityPreferences(
            enabledFeatures: ['voice_search'],
            preferencesReviewed: true,
          ),
        );
      await showFlow(tester, repo, onboarding: false);
      await tapLabel(tester, 'Review changes');
      expect(find.widgetWithText(SwitchListTile, 'Voice search'), findsNothing);
      expect(
        find.textContaining('not active in this app version'),
        findsOneWidget,
      );
      await tapLabel(tester, 'Confirm and save');
      expect(repo.value.preferences.enabledFeatures, ['voice_search']);
    },
  );
  testWidgets(
    'unreviewed active seeker confirms before dashboard and navigation',
    (tester) async {
      final repo = unreviewed();
      await tester.pumpWidget(
        MainApp(service: FakeSession(), repositoryBuilder: (_, _) => repo),
      );
      await tester.pumpAndSettle();
      expect(find.text('Accessibility assessment'), findsOneWidget);
      expect(find.text('Welcome, Dummy Seeker'), findsNothing);
      expect(find.byType(NavigationBar), findsNothing);
      await tapLabel(tester, 'Cancel');
      expect(repo.value.preferences.preferencesReviewed, false);
      expect(find.text('Welcome, Dummy Seeker'), findsNothing);
      await tapLabel(tester, 'Next');
      await tapLabel(tester, 'Next');
      await tapLabel(tester, 'Confirm and save');
      expect(find.text('Welcome, Dummy Seeker'), findsOneWidget);
      expect(find.byType(NavigationDestination), findsNWidgets(5));
    },
  );
  testWidgets(
    'reviewed seeker enters dashboard and Settings reuses AccessibilityScreen',
    (tester) async {
      final repo = FakeRepository();
      await tester.pumpWidget(
        MainApp(service: FakeSession(), repositoryBuilder: (_, _) => repo),
      );
      await tester.pumpAndSettle();
      expect(find.text('Welcome, Dummy Seeker'), findsOneWidget);
      await tester.tap(find.byType(NavigationDestination).at(4));
      await tester.pumpAndSettle();
      expect(find.byType(AccessibilityScreen), findsOneWidget);
      await tapLabel(tester, 'Edit accessibility needs');
      expect(find.text('Accessibility assessment'), findsOneWidget);
    },
  );
  for (final session in [
    FakeSession(id: null),
    FakeSession(allowed: false),
    AdministratorSession(),
  ]) {
    testWidgets(
      'missing or unauthorized account never constructs onboarding (${session.id},${session.allowed})',
      (tester) async {
        var constructed = 0;
        await tester.pumpWidget(
          MainApp(
            service: session,
            repositoryBuilder: (_, _) {
              constructed++;
              return unreviewed();
            },
          ),
        );
        await tester.pumpAndSettle();
        expect(constructed, 0);
        expect(find.byType(AccessibilityScreen), findsNothing);
        expect(find.text('Sign in'), findsOneWidget);
      },
    );
  }
  testWidgets('account switch disposes private draft before next assessment', (
    tester,
  ) async {
    final session = MutableSession();
    final a = unreviewed(), b = unreviewed();
    await tester.pumpWidget(
      MainApp(
        service: session,
        repositoryBuilder: (_, id) => id == 'dummy-a' ? a : b,
      ),
    );
    await tester.pumpAndSettle();
    await tapLabel(tester, 'Visual');
    session.current = null;
    session.events.add(const AuthState(AuthChangeEvent.signedOut, null));
    await tester.pumpAndSettle();
    expect(find.byType(AccessibilityScreen), findsNothing);
    session.current = 'dummy-b';
    session.events.add(const AuthState(AuthChangeEvent.signedIn, null));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<CheckboxListTile>(find.byKey(const ValueKey('need_visual')))
          .value,
      false,
    );
    expect(a.preferenceSaves, 0);
    await tester.pumpWidget(const SizedBox.shrink());
    await session.events.close();
  });
  testWidgets('large text and system Back retain draft across steps', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await showFlow(tester, unreviewed());
    await tapLabel(tester, 'Visual');
    await tapLabel(tester, 'Next');
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Accessibility assessment'), findsOneWidget);
    expect(
      tester
          .widget<CheckboxListTile>(find.byKey(const ValueKey('need_visual')))
          .value,
      true,
    );
    expect(tester.takeException(), isNull);
  });
  testWidgets('render implemented shared steps with synthetic private data', (
    tester,
  ) async {
    const output = String.fromEnvironment('FLOW_PREVIEW_DIR');
    const fonts = String.fromEnvironment('FLOW_FONT_DIR');
    if (fonts.isNotEmpty) {
      await tester.runAsync(() async {
        final font = FontLoader('Roboto')
          ..addFont(
            File('$fonts/roboto-regular.ttf')
                .readAsBytes()
                .then(ByteData.sublistView),
          );
        await font.load();
      });
    }
    tester.view.physicalSize = const Size(430, 930);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = SeekerController(
      unreviewed(),
      onPreferences: (_) {},
      onAccessLost: () {},
    );
    await controller.load();
    addTearDown(controller.dispose);
    final boundary = GlobalKey();
    await tester.pumpWidget(
      RepaintBoundary(
        key: boundary,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            fontFamily: 'Roboto',
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xff0038a8),
            ),
          ),
          home: Scaffold(
            appBar: AppBar(title: const Text('EnableWork+')),
            body: AccessibilityScreen(controller: controller, onboarding: true),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    for (final name in ['assessment', 'features', 'review']) {
      expect(tester.takeException(), isNull);
      if (output.isNotEmpty) {
        final render =
            boundary.currentContext!.findRenderObject()!
                as RenderRepaintBoundary;
        await tester.runAsync(() async {
          final image = await render.toImage(pixelRatio: 2);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          await File('$output/accessibility-flow-$name.png')
              .writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }
      if (name != 'review') await tapLabel(tester, 'Next');
    }
  });
}
