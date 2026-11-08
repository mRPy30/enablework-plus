import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/painting.dart';
import 'package:enablework_plus/models/seeker_workspace.dart';
import 'package:enablework_plus/services/seeker_repository.dart';
import 'package:enablework_plus/state/seeker_controller.dart';
import 'package:enablework_plus/utils/preference_text_scaler.dart';

import 'support/workspace_fakes.dart';

class RecordingBackend implements ResumeBackend {
  final calls = <String>[];
  bool reject = false;
  @override
  Future<String> beginUpload(String title) async {
    calls.add('begin');
    return 'dummy';
  }

  @override
  Future<void> putPdf(String id, PickedPdf file) async {
    calls.add('upload');
  }

  @override
  Future<void> finalize(String id) async {
    calls.add('finalize');
    if (reject) throw const WorkspaceFailure('Validation unavailable');
  }

  @override
  Future<void> remove(String id) async {
    calls.add('remove');
  }
}

void main() {
  test('profile payload contains no authority or owner fields', () {
    final value = SeekerProfile(
      userId: 'dummy',
      updatedAt: 'stamp',
      fields: {
        'full_name': 'Dummy',
        'role': 'system_administrator',
        'id': 'other',
        'skills': ' Testing, Testing, Communication ',
      },
    );
    expect(value.identityJson.keys.toSet(), {'full_name', 'phone'});
    expect(value.detailsJson.containsKey('role'), false);
    expect(value.detailsJson.containsKey('id'), false);
    expect(value.detailsJson['skills'], ['Testing', 'Communication']);
  });
  test(
    'completion never rewards optional phone or accommodation disclosure',
    () {
      final base = dummyProfile();
      final changed = SeekerProfile(
        userId: base.userId,
        updatedAt: base.updatedAt,
        fields: {
          ...base.fields,
          'phone': '+000 000000',
          'accommodation_needs': 'Dummy request',
        },
      );
      expect(changed.completionPercent, base.completionPercent);
    },
  );
  test('empty name and oversized skills fail validation', () {
    expect(validateProfileField('full_name', ' '), isNotNull);
    expect(validateProfileField('phone', '-------'), isNotNull);
    expect(validateProfileField('skills', 'x' * 121), isNotNull);
  });
  test(
    'invalid, oversized and disguised PDF input rejected before upload',
    () async {
      expect(
        () => PickedPdf(Uint8List.fromList('not pdf'.codeUnits)),
        throwsA(isA<WorkspaceFailure>()),
      );
      expect(
        () => PickedPdf(Uint8List(PickedPdf.maxBytes + 1)),
        throwsA(isA<WorkspaceFailure>()),
      );
      await expectLater(
        PickedPdf.read(Stream.value('%PDF-'.codeUnits), name: 'fake.exe'),
        throwsA(isA<WorkspaceFailure>()),
      );
    },
  );
  test('bounded stream catches dishonest file length', () async {
    await expectLater(
      PickedPdf.read(
        Stream.value(Uint8List(PickedPdf.maxBytes + 1)),
        name: 'dummy.pdf',
        declaredSize: 1,
      ),
      throwsA(isA<WorkspaceFailure>()),
    );
  });
  test('valid PDF stream can be read without exposing a local path', () async {
    final pdf = await PickedPdf.read(
      Stream.value('%PDF-1.4 dummy'.codeUnits),
      name: 'DUMMY.PDF',
    );
    expect(pdf.bytes.length, 14);
  });
  test(
    'resume lifecycle validates in order without unsafe cleanup on timeout',
    () async {
      final backend = RecordingBackend()..reject = true;
      await expectLater(
        ResumeLifecycle(backend).upload('Dummy', dummyPdf(), (_) {}),
        throwsA(isA<WorkspaceFailure>()),
      );
      expect(backend.calls, ['begin', 'upload', 'finalize']);
      expect(backend.calls, isNot(contains('remove')));
    },
  );
  test('invalid title never creates a pending record', () async {
    final backend = RecordingBackend();
    await expectLater(
      ResumeLifecycle(backend).upload(' ', dummyPdf(), (_) {}),
      throwsA(isA<WorkspaceFailure>()),
    );
    expect(backend.calls, isEmpty);
  });
  test('submitted and nonready resume actions are constrained', () {
    const ready = ResumeRecord(
      id: 'dummy',
      title: 'Dummy',
      status: ResumeStatus.ready,
      isSubmitted: true,
    );
    expect(ready.canRemove, false);
    expect(ready.canSelect, true);
    const pending = ResumeRecord(
      id: 'pending',
      title: 'Dummy',
      status: ResumeStatus.pending,
    );
    expect(pending.canSelect, false);
  });
  test('preference scaling composes with the system scaler', () {
    expect(const PreferenceTextScaler(TextScaler.linear(1.5), 2).scale(16), 48);
    expect(
      () => const AccessibilityPreferences(textScale: 3).validate(),
      throwsA(isA<WorkspaceFailure>()),
    );
  });
  test('late workspace response is ignored after disposal', () async {
    final repo = FakeRepository()..pendingLoad = Completer<SeekerWorkspace>();
    var applied = 0;
    final c = SeekerController(
      repo,
      onPreferences: (_) => applied++,
      onAccessLost: () {},
    );
    final task = c.load();
    c.dispose();
    repo.pendingLoad!.complete(dummyWorkspace());
    await task;
    expect(applied, 0);
    expect(c.data, null);
  });
  test(
    'access loss clears protected workspace and invalidates the gate',
    () async {
      final repo = FakeRepository();
      var denied = 0;
      final c = SeekerController(
        repo,
        onPreferences: (_) {},
        onAccessLost: () => denied++,
      );
      await c.load();
      repo.fail = const WorkspaceFailure('Access changed', accessLost: true);
      expect(await c.saveProfile(dummyProfile()), false);
      expect(c.data, null);
      expect(denied, 1);
      c.dispose();
    },
  );
  test('failed preference save does not apply unconfirmed settings', () async {
    final repo = FakeRepository();
    var current = const AccessibilityPreferences();
    final c = SeekerController(
      repo,
      onPreferences: (p) => current = p,
      onAccessLost: () {},
    );
    await c.load();
    repo.fail = const WorkspaceFailure('Connection unavailable');
    expect(
      await c.savePreferences(
        const AccessibilityPreferences(highContrast: true),
      ),
      false,
    );
    expect(current.highContrast, false);
    c.dispose();
  });
}
