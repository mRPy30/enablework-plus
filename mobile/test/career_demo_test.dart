import 'dart:async';

import 'package:enablework_plus/demo/demo_workspace.dart';
import 'package:enablework_plus/main_demo.dart';
import 'package:enablework_plus/models/career_preview.dart';
import 'package:enablework_plus/screens/applications_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _DelayedDemo extends DemoWorkspace {
  var request = Completer<List<SeekerApplication>>();
  @override
  Future<List<SeekerApplication>> applications() => request.future;
}

void main() {
  testWidgets(
    'offline seeker can filter, review, switch resumes and track one demo application',
    (t) async {
      t.view.physicalSize = const Size(400, 820);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      await t.pumpWidget(const ClientDemo());
      Future<void> tap(String label) async {
        final matches = find.text(label);
        if (matches.evaluate().isEmpty) {
          await t.scrollUntilVisible(
            matches,
            240,
            scrollable: find.byType(Scrollable).first,
          );
        }
        final target = matches.first;
        await t.ensureVisible(target);
        await t.tap(target);
        await t.pumpAndSettle();
      }

      await tap('Open seeker demo');
      expect(
        t
            .widgetList<NavigationDestination>(
              find.byType(NavigationDestination),
            )
            .map((d) => d.label),
        ['Home', 'Jobs', 'Applications', 'Profile', 'Settings'],
      );
      await tap('Applications');
      expect(find.text('No applications yet'), findsOneWidget);
      await tap('Browse jobs');
      await t.enterText(find.byType(TextField), 'catalog');
      await t.pumpAndSettle();
      await tap('Work arrangement');
      await tap('Remote');
      expect(find.text('No matching jobs'), findsOneWidget);
      await tap('Hybrid');
      await tap('View job');
      expect(find.text('Workplace accessibility'), findsOneWidget);
      await tap('Review application');
      await tap('Manage resumes');
      await tap('Add sample resume');
      await t.tap(find.byType(BackButton));
      await t.pumpAndSettle();
      await tap('Sample resume 1');
      await tap('Save demo application');
      await tap('View application');
      expect(find.text('Sample resume 1'), findsOneWidget);
      expect(find.text('Submitted'), findsOneWidget);
      await tap('Home');
      await t.scrollUntilVisible(
        find.text('1 total application'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tap('Exit demo');
      await tap('Open seeker demo');
      await tap('Applications');
      expect(find.text('No applications yet'), findsOneWidget);
    },
  );

  testWidgets(
    'Jobs and Applications support large Android text and accessible tap targets',
    (t) async {
      t.view.physicalSize = const Size(360, 800);
      t.view.devicePixelRatio = 1;
      t.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
      await t.pumpWidget(const ClientDemo());
      final enter = find.text('Open seeker demo');
      await t.ensureVisible(enter);
      await t.pumpAndSettle();
      await t.tap(enter);
      await t.pumpAndSettle();
      for (final tab in [1, 2]) {
        await t.tap(find.byType(NavigationDestination).at(tab));
        await t.pumpAndSettle();
        expect(t.takeException(), isNull);
        await expectLater(t, meetsGuideline(androidTapTargetGuideline));
      }
    },
  );

  testWidgets(
    'applications can recover from an error without treating it as an empty history',
    (t) async {
      final source = _DelayedDemo();
      await t.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ApplicationsScreen(
              preview: source,
              revision: 0,
              onOpen: (_) {},
              browse: () {},
            ),
          ),
        ),
      );
      expect(find.text('Loading applications'), findsOneWidget);
      source.request.completeError(StateError('preview unavailable'));
      await t.pumpAndSettle();
      expect(find.text('Applications could not be loaded'), findsOneWidget);
      source.request = Completer<List<SeekerApplication>>()..complete([]);
      await t.tap(find.text('Try again'));
      await t.pumpAndSettle();
      expect(find.text('No applications yet'), findsOneWidget);
    },
  );
}
