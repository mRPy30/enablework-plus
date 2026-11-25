import 'package:enablework_plus/widgets/welcome_guide.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('personal greeting uses the still guide when motion is reduced', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: MediaQuery(
            data: MediaQueryData(disableAnimations: true),
            child: WelcomeGuide(name: 'Verzel'),
          ),
        ),
      ),
    );
    expect(find.text('Hello, Verzel!'), findsOneWidget);
    expect(
      tester.widget<Image>(find.byType(Image)).image,
      const AssetImage('assets/guide/hello-still.png'),
    );
    expect(find.text('Play FSL hello'), findsOneWidget);
    final spoken = <String>[];
    const channel = MethodChannel('enablework_plus/tts');
    final messenger = tester.binding.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(channel, (c) async {
      spoken.add(c.arguments['text'] as String);
      return null;
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
    await tester.tap(find.byTooltip('Read greeting aloud'));
    await tester.pump();
    expect(spoken.single, contains('Verzel'));
  });
}
