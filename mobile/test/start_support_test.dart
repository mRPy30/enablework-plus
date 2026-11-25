import 'package:enablework_plus/main.dart';
import 'package:enablework_plus/screens/start_support_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('FSL resources open before sign-in and back returns to setup', (
    tester,
  ) async {
    await tester.pumpWidget(const MainApp(deviceSupport: true));
    await tester.tap(find.text('Filipino Sign Language resources'));
    await tester.pumpAndSettle();
    expect(find.text('Watch greetings in FSL'), findsOneWidget);
    expect(find.text('Look up a sign'), findsOneWidget);
    expect(find.text('Practice a sign on camera'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Welcome to EnableWork+'), findsOneWidget);
  });
  testWidgets('first launch previews and remembers multiple supports', (
    tester,
  ) async {
    FlutterSecureStorage.setMockInitialValues({});
    await tester.pumpWidget(const MainApp(deviceSupport: true));
    await tester.scrollUntilVisible(
      find.text('Larger text and stronger contrast'),
      150,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.text('Larger text and stronger contrast'));
    await tester.pumpAndSettle();
    final context = tester.element(find.text('Welcome to EnableWork+'));
    expect(MediaQuery.textScalerOf(context).scale(20), greaterThan(20));
    await tester.scrollUntilVisible(
      find.text('Reduce animations'),
      150,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.text('Reduce animations'));
    await tester.pumpAndSettle();
    expect(MediaQuery.disableAnimationsOf(context), isTrue);
    await tester.scrollUntilVisible(
      find.text('Continue'),
      150,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    final saved = await StartPreferences.load();
    expect(saved, {StartSupport.reading, StartSupport.calm});
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(
      MainApp(deviceSupport: true, initialSupport: saved),
    );
    expect(find.text('Welcome to EnableWork+'), findsNothing);
    expect(
      MediaQuery.textScalerOf(tester.element(find.text('Display and controls')))
          .scale(20),
      greaterThan(20),
    );
    await tester.tap(find.text('Display and controls'));
    await tester.pumpAndSettle();
    expect(find.text('Welcome to EnableWork+'), findsOneWidget);
  });
}
