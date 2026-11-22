import 'package:enablework_admin/screens/admin_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('admin shell exposes only approved management areas', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(home: AdminShell(onSignOut: () async {})),
    );
    await tester.pumpAndSettle();

    expect(find.text('PWD Job Seekers'), findsOneWidget);
    expect(find.text('Companies'), findsOneWidget);
    expect(find.text('Job Postings'), findsOneWidget);
    expect(find.text('Applications'), findsOneWidget);
    expect(find.text('System Activity'), findsOneWidget);
    expect(find.text('Employer Login'), findsNothing);
    expect(find.text('AI matching deferred'), findsOneWidget);

    await tester.tap(find.text('Companies'));
    await tester.pumpAndSettle();
    expect(find.text('No company records loaded'), findsOneWidget);
    expect(find.textContaining('do not have accounts'), findsOneWidget);
  });
}
