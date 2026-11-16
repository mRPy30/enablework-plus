import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:enablework_plus/models/account_profile.dart';
import 'package:enablework_plus/models/seeker_workspace.dart';
import 'package:enablework_plus/services/auth_service.dart';
import 'package:enablework_plus/services/seeker_repository.dart';
import 'package:enablework_plus/state/seeker_controller.dart';

import 'support/workspace_fakes.dart';

// Tests the real Supabase/PostgREST client over loopback HTTP. This fixture is
// not a replacement for the PostgreSQL RLS tests or live Supabase service suite.
class FixtureAuth extends AuthService {
  FixtureAuth(SupabaseClient client)
    : super(client, 'com.enableworkplus.app://auth/callback');
  String? current = 'dummy-a';
  bool allowed = true;
  @override
  String? get userId => current;
  @override
  Future<AccountProfile> requireAccess() async {
    if (!allowed || current == null) throw StateError('Denied');
    return const AccountProfile(AppRole.jobSeeker);
  }
}

class DelayedPreferences extends FakeRepository {
  final gate = Completer<void>();
  @override
  Future<void> savePreferences(AccessibilityPreferences value) async {
    await gate.future;
    await super.savePreferences(value);
  }
}

void main() {
  late HttpServer server;
  late SupabaseClient client;
  late FixtureAuth auth;
  late SupabaseSeekerRepository repository;
  late List<Map<String, dynamic>> patches;
  late List<Uri> requests;
  bool conflict = false;
  Completer<void>? enteredPatch;
  Completer<void>? releasePatch;
  const version = '2026-11-09T01:00:00.123456+00:00';

  setUp(() async {
    conflict = false;
    patches = [];
    requests = [];
    enteredPatch = null;
    releasePatch = null;
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      requests.add(request.uri);
      request.response.headers.contentType = ContentType.json;
      if (request.method == 'PATCH') {
        patches.add(
          Map<String, dynamic>.from(
            jsonDecode(await utf8.decoder.bind(request).join()) as Map,
          ),
        );
        enteredPatch?.complete();
        if (releasePatch != null) await releasePatch!.future;
        // PATCH + maybeSingle requests PostgREST's singular representation.
        expect(
          request.headers.value('accept'),
          'application/vnd.pgrst.object+json',
        );
        request.response.headers.set(
          'content-type',
          'application/vnd.pgrst.object+json',
        );
        if (conflict) {
          request.response.statusCode = 406;
          request.response.write(
            jsonEncode({
              'code': 'PGRST116',
              'message': 'Cannot coerce the result to a single JSON object',
              'details': 'Results contain 0 rows',
              'hint': null,
            }),
          );
        } else {
          request.response.write(jsonEncode({'user_id': 'dummy-a'}));
        }
      } else {
        request.response.write(jsonEncode({'updated_at': version}));
      }
      await request.response.close();
    });
    client = SupabaseClient(
      'http://127.0.0.1:${server.port}',
      'dummy-public-fixture-key',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
    );
    auth = FixtureAuth(client);
    repository = SupabaseSeekerRepository(auth, 'dummy-a');
  });
  tearDown(() async {
    if (releasePatch != null && !releasePatch!.isCompleted) {
      releasePatch!.complete();
    }
    await client.dispose();
    await server.close(force: true);
  });

  test(
    'single guarded PATCH carries full choices and exact owner/read version',
    () async {
      await repository.savePreferences(
        const AccessibilityPreferences(
          textScale: 1.5,
          highContrast: true,
          reduceMotion: true,
          accessibilityNeeds: ['visual', 'hearing'],
          enabledFeatures: ['step_by_step_guidance'],
          preferencesReviewed: true,
          updatedAt: version,
        ),
      );
      expect(requests.length, 1);
      expect(
        patches.single.keys,
        unorderedEquals([
          'text_scale',
          'high_contrast',
          'reduce_motion',
          'accessibility_needs',
          'enabled_features',
          'preferences_reviewed',
        ]),
      );
      expect(requests.single.queryParameters['user_id'], 'eq.dummy-a');
      expect(requests.single.queryParameters['updated_at'], 'eq.$version');
      expect(patches.single.containsKey('user_id'), false);
      expect(patches.single.containsKey('updated_at'), false);
    },
  );
  test('legacy single-setting PATCH omits all unrelated fields', () async {
    await repository.savePreferences(
      const AccessibilityPreferences(highContrast: true),
    );
    expect(requests.length, 2);
    expect(patches.single, {'high_contrast': true});
    expect(requests.last.queryParameters['updated_at'], 'eq.$version');
  });
  test(
    'stale version reports conflict rather than unconditional overwrite',
    () async {
      conflict = true;
      await expectLater(
        repository.savePreferences(
          const AccessibilityPreferences(
            highContrast: true,
            updatedAt: version,
          ),
        ),
        throwsA(
          isA<WorkspaceFailure>().having(
            (e) => e.message,
            'message',
            contains('changed elsewhere'),
          ),
        ),
      );
      expect(patches.length, 1);
      expect(requests.single.queryParameters['updated_at'], 'eq.$version');
    },
  );
  test('invalid needs rejected before any HTTP mutation', () async {
    await expectLater(
      repository.savePreferences(
        const AccessibilityPreferences(accessibilityNeeds: ['forged']),
      ),
      throwsA(isA<WorkspaceFailure>()),
    );
    expect(requests, isEmpty);
  });
  test('changed account denied before any private request', () async {
    auth.current = 'dummy-b';
    await expectLater(
      repository.savePreferences(
        const AccessibilityPreferences(preferencesReviewed: true),
      ),
      throwsA(
        isA<WorkspaceFailure>().having((e) => e.accessLost, 'accessLost', true),
      ),
    );
    expect(requests, isEmpty);
  });
  test('expired session denied before any private request', () async {
    auth.current = null;
    await expectLater(
      repository.savePreferences(
        const AccessibilityPreferences(highContrast: true),
      ),
      throwsA(
        isA<WorkspaceFailure>().having((e) => e.accessLost, 'accessLost', true),
      ),
    );
    expect(requests, isEmpty);
  });
  test('denied account cannot save choices', () async {
    auth.allowed = false;
    await expectLater(
      repository.savePreferences(
        const AccessibilityPreferences(enabledFeatures: ['voice_search']),
      ),
      throwsA(
        isA<WorkspaceFailure>().having((e) => e.accessLost, 'accessLost', true),
      ),
    );
    expect(requests, isEmpty);
  });
  test('account change during request rejects the old response', () async {
    enteredPatch = Completer<void>();
    releasePatch = Completer<void>();
    final task = repository.savePreferences(
      const AccessibilityPreferences(highContrast: true, updatedAt: version),
    );
    final expectation = expectLater(
      task,
      throwsA(
        isA<WorkspaceFailure>().having((e) => e.accessLost, 'accessLost', true),
      ),
    );
    await enteredPatch!.future;
    auth.current = 'dummy-b';
    releasePatch!.complete();
    await expectation;
  });
  test('empty patch does not make a network request', () async {
    await repository.savePreferences(const AccessibilityPreferences());
    expect(requests, isEmpty);
  });
  test(
    'disposed workspace never applies a late private preference save',
    () async {
      final fake = DelayedPreferences()
        ..value = dummyWorkspace(
          preferences: const AccessibilityPreferences(
            accessibilityNeeds: ['visual'],
            enabledFeatures: ['step_by_step_guidance'],
            preferencesReviewed: true,
          ),
        );
      var applied = 0;
      final controller = SeekerController(
        fake,
        onPreferences: (_) => applied++,
        onAccessLost: () {},
      );
      await controller.load();
      final before = applied;
      final save = controller.savePreferences(
        const AccessibilityPreferences(highContrast: true),
      );
      controller.dispose();
      fake.gate.complete();
      expect(await save, false);
      expect(controller.data, null);
      expect(applied, before);
    },
  );
}
