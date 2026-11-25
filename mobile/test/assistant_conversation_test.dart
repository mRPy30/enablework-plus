import 'package:enablework_plus/widgets/ai_assistant_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'spoken question gets a visible and spoken answer; sige opens the suggested tool',
    (tester) async {
      final messenger = tester.binding.defaultBinaryMessenger;
      const mic = MethodChannel('enablework_plus/voice_search');
      const tts = MethodChannel('enablework_plus/tts');
      var question = 'Paano mag scan ng resume?';
      var spokenReply = '';
      var opened = 0;
      messenger.setMockMethodCallHandler(mic, (call) async => question);
      messenger.setMockMethodCallHandler(tts, (call) async {
        if (call.method == 'speak')
          spokenReply = call.arguments['text'] as String;
        return null;
      });
      addTearDown(() {
        messenger.setMockMethodCallHandler(mic, null);
        messenger.setMockMethodCallHandler(tts, null);
      });
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AiAssistantSheet(
              onScanResume: () => opened++,
              onFindMatch: () {},
              onBuildResume: () {},
              onAccessibility: () {},
              onSignLanguage: () {},
              matchingAvailable: true,
            ),
          ),
        ),
      );
      await tester.tap(find.text('Talk to Assistant'));
      await tester.pumpAndSettle();
      expect(spokenReply, contains('Manage resumes'));
      expect(find.text(spokenReply), findsOneWidget);
      expect(opened, 0);
      question = 'paano';
      await tester.tap(find.text('Talk to Assistant'));
      await tester.pumpAndSettle();
      expect(spokenReply, contains('Open resumes'));
      question = 'sige';
      await tester.tap(find.text('Talk to Assistant'));
      await tester.pumpAndSettle();
      expect(opened, 1);
    },
  );
}
