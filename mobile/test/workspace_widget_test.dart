import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:enablework_plus/models/seeker_workspace.dart';
import 'package:enablework_plus/screens/seeker_home.dart';

import 'support/workspace_fakes.dart';

Widget fixture(
  FakeRepository repo, {
  FakePicker? picker,
  double scale = 1,
  bool reduce = false,
}) => MaterialApp(
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(
      context,
    ).copyWith(textScaler: TextScaler.linear(scale), disableAnimations: reduce),
    child: child!,
  ),
  home: Scaffold(
    body: SeekerHome(
      repository: repo,
      picker: picker ?? FakePicker(null),
      onPreferences: (_) {},
      onAccessLost: () {},
      onSignOut: () async {},
    ),
  ),
);
void main() {
  testWidgets('dashboard shows own counts and navigation', (tester) async {
    await tester.pumpWidget(fixture(FakeRepository()));
    await tester.pumpAndSettle();
    expect(find.text('Welcome, Dummy Seeker'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('3 total applications'),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('3 total applications'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Edit profile'),
      -400,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit profile').hitTestable());
    await tester.pumpAndSettle();
    expect(find.text('Personal details'), findsOneWidget);
  });
  testWidgets('profile edit saves through the scoped controller', (
    tester,
  ) async {
    final repo = FakeRepository();
    await tester.pumpWidget(fixture(repo));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('profile_full_name')),
      'Edited Dummy',
    );
    await tester.scrollUntilVisible(
      find.text('Save profile'),
      500,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Save profile'));
    await tester.pumpAndSettle();
    expect(repo.saves, 1);
    expect(repo.value.profile.fields['full_name'], 'Edited Dummy');
  });
  testWidgets('canceling picker creates no upload', (tester) async {
    final repo = FakeRepository();
    await tester.pumpWidget(fixture(repo));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(NavigationDestination).at(3));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Manage resumes'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Choose PDF and upload'));
    await tester.pumpAndSettle();
    expect(repo.uploads, 0);
  });
  testWidgets('PDF selection completes upload and displays resume', (
    tester,
  ) async {
    final repo = FakeRepository();
    await tester.pumpWidget(fixture(repo, picker: FakePicker(dummyPdf())));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(NavigationDestination).at(3));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Manage resumes'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Choose PDF and upload'));
    await tester.pumpAndSettle();
    expect(repo.uploads, 1);
    expect(find.text('Available'), findsOneWidget);
  });
  testWidgets('submitted resume has no remove action', (tester) async {
    final repo = FakeRepository()
      ..value = dummyWorkspace(
        resumes: [
          const ResumeRecord(
            id: 'dummy',
            title: 'Submitted dummy',
            status: ResumeStatus.ready,
            isSubmitted: true,
          ),
        ],
      );
    await tester.pumpWidget(fixture(repo));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(NavigationDestination).at(3));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Manage resumes'));
    await tester.pumpAndSettle();
    expect(find.text('Used in an application'), findsOneWidget);
    expect(find.text('Remove'), findsNothing);
  });
  testWidgets('saving preferences persists chosen controls', (tester) async {
    final repo = FakeRepository();
    await tester.pumpWidget(fixture(repo));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(NavigationDestination).at(4));
    await tester.pumpAndSettle();
    await tester.tap(find.text('High contrast'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Review changes'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Review changes').hitTestable());
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Confirm and save'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirm and save').hitTestable());
    await tester.pumpAndSettle();
    expect(repo.value.preferences.highContrast, true);
  });
  testWidgets(
    'large text and reduced motion avoid layout errors on narrow screens',
    (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        fixture(FakeRepository(), scale: 2, reduce: true),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), null);
      await tester.tap(find.byType(NavigationDestination).at(4));
      await tester.pumpAndSettle();
      expect(tester.takeException(), null);
    },
  );
  testWidgets('load failure offers retry without exposing private data', (
    tester,
  ) async {
    final repo = FakeRepository()
      ..fail = const WorkspaceFailure('Connection unavailable.');
    await tester.pumpWidget(fixture(repo));
    await tester.pumpAndSettle();
    expect(find.text('Try again'), findsOneWidget);
    expect(find.text('Dummy Seeker'), findsNothing);
    repo.fail = null;
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(find.text('Welcome, Dummy Seeker'), findsOneWidget);
  });
}
