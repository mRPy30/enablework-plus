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
  group('accessibility preference foundation', () {
    Map<String, dynamic> legacy() => {
      'text_scale': 1.75,
      'high_contrast': true,
      'reduce_motion': true,
    };
    AccessibilityPreferences stored() => AccessibilityPreferences.fromJson({
      ...legacy(),
      'accessibility_needs': ['visual', 'hearing'],
      'enabled_features': ['step_by_step_guidance'],
      'preferences_reviewed': true,
      'updated_at': '2026-11-09T01:00:00.123456Z',
    });
    for (final need in AccessibilityPreferences.allowedNeeds) {
      test('accepts need $need without enabling features', () {
        final p = AccessibilityPreferences(accessibilityNeeds: [need]);
        p.validate();
        expect(p.enabledFeatures, isEmpty);
        expect(p.preferencesReviewed, false);
      });
    }
    for (final feature in AccessibilityPreferences.allowedFeatures) {
      test('accepts scheduled feature ID $feature without inferring needs', () {
        final p = AccessibilityPreferences(enabledFeatures: [feature]);
        p.validate();
        expect(p.accessibilityNeeds, isEmpty);
      });
    }
    test('all seven needs and multiple independent choices are valid', () {
      final p = AccessibilityPreferences(
        accessibilityNeeds: AccessibilityPreferences.allowedNeeds.toList(),
        enabledFeatures: const ['voice_guidance', 'simplified_language'],
      );
      p.validate();
      expect(p.accessibilityNeeds.length, 7);
      expect(p.enabledFeatures.length, 2);
    });
    test('empty choices and unreviewed are safe defaults', () {
      const p = AccessibilityPreferences();
      p.validate();
      expect(p.accessibilityNeeds, isEmpty);
      expect(p.enabledFeatures, isEmpty);
      expect(p.preferencesReviewed, false);
      expect(p.textScale, 1);
    });
    for (final invalid in [
      const AccessibilityPreferences(accessibilityNeeds: ['unknown']),
      const AccessibilityPreferences(accessibilityNeeds: ['visual', 'visual']),
      AccessibilityPreferences(accessibilityNeeds: List.filled(8, 'visual')),
      const AccessibilityPreferences(enabledFeatures: ['high_contrast']),
      const AccessibilityPreferences(
        enabledFeatures: ['voice_search', 'voice_search'],
      ),
    ]) {
      test('rejects invalid/duplicate selection ${invalid.json}', () {
        expect(invalid.validate, throwsA(isA<WorkspaceFailure>()));
      });
    }
    test('legacy deserialization preserves original preferences', () {
      final p = AccessibilityPreferences.fromJson(legacy());
      expect(p.textScale, 1.75);
      expect(p.highContrast, true);
      expect(p.reduceMotion, true);
      expect(p.accessibilityNeeds, isEmpty);
      expect(p.enabledFeatures, isEmpty);
      expect(p.preferencesReviewed, false);
    });
    test('rejects explicit nulls, invalid types and invalid review flags', () {
      for (final patch in <Map<String, dynamic>>[
        {'accessibility_needs': null},
        {
          'accessibility_needs': [null],
        },
        {'enabled_features': 'voice_search'},
        {
          'enabled_features': [1],
        },
        {'preferences_reviewed': null},
        {'preferences_reviewed': 'true'},
      ]) {
        expect(
          () => AccessibilityPreferences.fromJson({...legacy(), ...patch}),
          throwsA(isA<WorkspaceFailure>()),
        );
      }
    });
    test('round trip preserves full values and read version separately', () {
      final p = stored();
      final next = AccessibilityPreferences.fromJson(p.json);
      expect(next.json, p.json);
      expect(p.json.containsKey('updated_at'), false);
      expect(
        p.updateJson.keys,
        unorderedEquals([
          'text_scale',
          'high_contrast',
          'reduce_motion',
          'accessibility_needs',
          'enabled_features',
          'preferences_reviewed',
        ]),
      );
    });
    test('legacy three-field editor does not clear new selections', () {
      final p = const AccessibilityPreferences(
        textScale: 2,
        highContrast: false,
        reduceMotion: false,
      ).mergeOnto(stored());
      expect(p.accessibilityNeeds, ['visual', 'hearing']);
      expect(p.enabledFeatures, ['step_by_step_guidance']);
      expect(p.preferencesReviewed, true);
      expect(p.textScale, 2);
      expect(p.updatedAt, stored().updatedAt);
    });
    test(
      'single-setting patch preserves unrelated original and new values',
      () {
        final patch = const AccessibilityPreferences(highContrast: false);
        expect(patch.updateJson, {'high_contrast': false});
        final p = patch.mergeOnto(stored());
        expect(p.highContrast, false);
        expect(p.textScale, 1.75);
        expect(p.reduceMotion, true);
        expect(p.preferencesReviewed, true);
        expect(p.accessibilityNeeds, stored().accessibilityNeeds);
      },
    );
    test('explicit empty arrays and false clear only the intended choices', () {
      final p = const AccessibilityPreferences(
        accessibilityNeeds: [],
        enabledFeatures: [],
        preferencesReviewed: false,
      ).mergeOnto(stored());
      expect(p.accessibilityNeeds, isEmpty);
      expect(p.enabledFeatures, isEmpty);
      expect(p.preferencesReviewed, false);
      expect(p.textScale, 1.75);
    });
    test('copyWith retains values and collections cannot be mutated', () {
      final p = stored().copyWith(textScale: 1.5);
      expect(p.accessibilityNeeds, stored().accessibilityNeeds);
      expect(() => p.accessibilityNeeds.add('speech'), throwsUnsupportedError);
      expect(() => p.enabledFeatures.clear(), throwsUnsupportedError);
      expect(p.updatedAt, stored().updatedAt);
    });
    test('an explicitly stale version is not replaced by a fresh baseline', () {
      final p = const AccessibilityPreferences(
        highContrast: false,
        updatedAt: 'old-version',
      ).mergeOnto(stored());
      expect(p.updatedAt, 'old-version');
    });
    test(
      'controller preserves new choices through existing Settings save',
      () async {
        final repo = FakeRepository()
          ..value = dummyWorkspace(preferences: stored());
        var applied = const AccessibilityPreferences();
        final c = SeekerController(
          repo,
          onPreferences: (p) => applied = p,
          onAccessLost: () {},
        );
        await c.load();
        expect(
          await c.savePreferences(
            const AccessibilityPreferences(
              textScale: 1.25,
              highContrast: false,
              reduceMotion: false,
            ),
          ),
          true,
        );
        expect(applied.accessibilityNeeds, ['visual', 'hearing']);
        expect(applied.enabledFeatures, ['step_by_step_guidance']);
        expect(applied.preferencesReviewed, true);
        expect(applied.textScale, 1.25);
        c.dispose();
        expect(c.data, null);
      },
    );
    test('invalid choices never replace controller data', () async {
      final repo = FakeRepository()
        ..value = dummyWorkspace(preferences: stored());
      final c = SeekerController(
        repo,
        onPreferences: (_) {},
        onAccessLost: () {},
      );
      await c.load();
      expect(
        await c.savePreferences(
          const AccessibilityPreferences(accessibilityNeeds: ['forged']),
        ),
        false,
      );
      expect(c.data!.preferences.accessibilityNeeds, ['visual', 'hearing']);
      c.dispose();
    });
  });
}
