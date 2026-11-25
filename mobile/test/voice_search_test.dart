import 'package:enablework_plus/models/career_preview.dart';
import 'package:enablework_plus/screens/jobs_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'job details speak real listing fields on request and stop on demand',
    (tester) async {
      const tts = MethodChannel('enablework_plus/tts');
      final calls = <MethodCall>[];
      final messenger = tester.binding.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(tts, (call) async {
        calls.add(call);
        return null;
      });
      addTearDown(() => messenger.setMockMethodCallHandler(tts, null));
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: JobDetails(
              job: const JobListing(
                '1',
                'Encoder',
                'Office',
                'Manila',
                'remote',
                'full_time',
                'Check records',
                ['Step-free entrance'],
                qualifications: 'Spreadsheet experience',
              ),
              applied: false,
              onReview: () {},
            ),
          ),
        ),
      );
      expect(calls, isEmpty);
      await tester.tap(find.text('Read job details aloud'));
      await tester.pump();
      final text = calls.single.arguments['text'] as String;
      for (final field in [
        'Encoder',
        'Office',
        'Manila',
        'Check records',
        'Step-free entrance',
        'Spreadsheet experience',
      ]) {
        expect(text, contains(field));
      }
      await tester.tap(find.byTooltip('Stop speech'));
      await tester.pump();
      expect(calls.last.method, 'stop');
    },
  );

  testWidgets('spoken skills filter jobs and cancellation keeps the query', (
    tester,
  ) async {
    const channel = MethodChannel('enablework_plus/voice_search');
    final messenger = tester.binding.defaultBinaryMessenger;
    String? transcript = 'Excel';
    messenger.setMockMethodCallHandler(channel, (call) async {
      expect(call.method, 'listen');
      return transcript;
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: JobsScreen.authenticated(
            loadJobs: () async => const [
              JobListing(
                '1',
                'Encoder',
                'Office',
                'Manila',
                'remote',
                'full_time',
                '',
                [],
                requiredSkills: ['Excel'],
              ),
              JobListing(
                '2',
                'Cook',
                'Cafe',
                'Manila',
                'onsite',
                'full_time',
                '',
                [],
              ),
            ],
            onOpen: (_) {},
            onAccessLost: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final mic = find.byTooltip('Search jobs by voice');
    await tester.tap(mic);
    await tester.pumpAndSettle();
    expect(find.text('Excel'), findsOneWidget);
    expect(find.text('1 opening'), findsOneWidget);
    transcript = null;
    await tester.tap(mic);
    await tester.pumpAndSettle();
    expect(find.text('Excel'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Cook');
    await tester.pump();
    expect(find.text('1 opening'), findsOneWidget);
  });
}
