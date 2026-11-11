import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:enablework_plus/main.dart';
import 'package:enablework_plus/models/account_profile.dart';
import 'package:enablework_plus/models/seeker_workspace.dart';
import 'package:enablework_plus/services/auth_service.dart';
import 'package:enablework_plus/services/seeker_repository.dart';

import 'support/workspace_fakes.dart';

class FakeSession implements AuthService {
  FakeSession({this.id = 'dummy-a', this.allowed = true});
  final String? id;
  final bool allowed;
  int clientReads = 0;
  @override
  SupabaseClient get client {
    clientReads++;
    throw StateError('No client may be used in this test');
  }

  @override
  String get redirectUrl => 'com.enableworkplus.app://auth/callback';
  @override
  String? get userId => id;
  @override
  bool get hasSession => id != null;
  @override
  Stream<AuthState> get authChanges => const Stream.empty();
  @override
  Future<AccountProfile> requireAccess() async {
    if (!allowed) throw StateError('Denied');
    return const AccountProfile(AppRole.jobSeeker);
  }

  @override
  Future<void> signIn(String email, String password) async {}
  @override
  Future<void> signUp(String email, String password, String fullName) async {}
  @override
  Future<void> signOut() async {}
  @override
  Future<void> requestPasswordReset(String email) async {}
  @override
  Future<void> updatePassword(String password) async {}
}

class MutableSession extends FakeSession {
  String? current = 'dummy-a';
  final events = StreamController<AuthState>.broadcast();
  @override
  String? get userId => current;
  @override
  bool get hasSession => current != null;
  @override
  Stream<AuthState> get authChanges => events.stream;
}

void main() {
  test(
    'repository refuses a changed session before any client operation',
    () async {
      final auth = FakeSession(id: 'dummy-b');
      final repo = SupabaseSeekerRepository(auth, 'dummy-a');
      await expectLater(
        repo.setCurrent('dummy-pdf'),
        throwsA(
          isA<WorkspaceFailure>().having(
            (x) => x.accessLost,
            'access lost',
            true,
          ),
        ),
      );
      expect(auth.clientReads, 0);
    },
  );
  test(
    'repository refuses suspended/denied access before data operations',
    () async {
      final auth = FakeSession(allowed: false);
      final repo = SupabaseSeekerRepository(auth, 'dummy-a');
      await expectLater(
        repo.remove('dummy-pdf'),
        throwsA(
          isA<WorkspaceFailure>().having(
            (x) => x.accessLost,
            'access lost',
            true,
          ),
        ),
      );
      expect(auth.clientReads, 0);
    },
  );
  test(
    'repository cannot submit a profile belonging to another user',
    () async {
      final auth = FakeSession();
      final repo = SupabaseSeekerRepository(auth, 'dummy-a');
      final foreign = SeekerProfile(
        userId: 'dummy-b',
        updatedAt: 'stamp',
        fields: {'full_name': 'Other dummy'},
      );
      await expectLater(
        repo.saveProfile(foreign),
        throwsA(
          isA<WorkspaceFailure>().having(
            (x) => x.accessLost,
            'access lost',
            true,
          ),
        ),
      );
      expect(auth.clientReads, 0);
    },
  );
  testWidgets('missing session never constructs a protected repository', (
    tester,
  ) async {
    var constructed = 0;
    await tester.pumpWidget(
      MainApp(
        service: FakeSession(id: null),
        repositoryBuilder: (_, _) {
          constructed++;
          return FakeRepository();
        },
      ),
    );
    await tester.pumpAndSettle();
    expect(constructed, 0);
    expect(find.text('Sign in'), findsOneWidget);
    expect(find.text('Welcome, Dummy Seeker'), findsNothing);
  });
  testWidgets('denied account never constructs a protected repository', (
    tester,
  ) async {
    var constructed = 0;
    await tester.pumpWidget(
      MainApp(
        service: FakeSession(allowed: false),
        repositoryBuilder: (_, _) {
          constructed++;
          return FakeRepository();
        },
      ),
    );
    await tester.pumpAndSettle();
    expect(constructed, 0);
    expect(find.text('Sign in'), findsOneWidget);
  });
  testWidgets('confirmed preferences apply across the protected app', (
    tester,
  ) async {
    final repo = FakeRepository()
      ..value = dummyWorkspace(
        preferences: const AccessibilityPreferences(
          textScale: 1.5,
          preferencesReviewed: true,
          highContrast: true,
          reduceMotion: true,
        ),
      );
    await tester.pumpWidget(
      MainApp(service: FakeSession(), repositoryBuilder: (_, _) => repo),
    );
    await tester.pumpAndSettle();
    final context = tester.element(find.text('Welcome, Dummy Seeker'));
    expect(MediaQuery.textScalerOf(context).scale(16), 24);
    expect(MediaQuery.disableAnimationsOf(context), true);
    final expected = ColorScheme.fromSeed(
      seedColor: const Color(0xff0038a8),
      contrastLevel: 1,
    );
    expect(Theme.of(context).colorScheme.primary, expected.primary);
  });
  testWidgets(
    'Android reduced-motion setting is honored without an app override',
    (tester) async {
      tester.binding.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.binding.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      await tester.pumpWidget(
        MainApp(
          service: FakeSession(),
          repositoryBuilder: (_, _) => FakeRepository(),
        ),
      );
      await tester.pumpAndSettle();
      final context = tester.element(find.text('Welcome, Dummy Seeker'));
      expect(MediaQuery.disableAnimationsOf(context), true);
      expect(Theme.of(context).splashFactory, NoSplash.splashFactory);
    },
  );
  testWidgets('account change clears old profile and accessibility state', (
    tester,
  ) async {
    final session = MutableSession();
    final first = FakeRepository()
      ..value = dummyWorkspace(
        preferences: const AccessibilityPreferences(
          textScale: 2,
          accessibilityNeeds: ['visual'],
          enabledFeatures: ['step_by_step_guidance'],
          preferencesReviewed: true,
          highContrast: true,
        ),
      );
    final second = FakeRepository()
      ..value = SeekerWorkspace(
        profile: SeekerProfile(
          userId: 'dummy-b',
          updatedAt: 'stamp',
          fields: {'full_name': 'Second Dummy'},
        ),
        preferences: const AccessibilityPreferences(preferencesReviewed: true),
        resumes: [],
        applicationCounts: {},
      );
    await tester.pumpWidget(
      MainApp(
        service: session,
        repositoryBuilder: (_, id) => id == 'dummy-a' ? first : second,
      ),
    );
    await tester.pumpAndSettle();
    session.current = null;
    session.events.add(const AuthState(AuthChangeEvent.signedOut, null));
    await tester.pumpAndSettle();
    expect(find.text('Welcome, Dummy Seeker'), findsNothing);
    expect(
      MediaQuery.textScalerOf(tester.element(find.text('Sign in'))).scale(16),
      16,
    );
    session.current = 'dummy-b';
    session.events.add(const AuthState(AuthChangeEvent.signedIn, null));
    await tester.pumpAndSettle();
    expect(find.text('Welcome, Second Dummy'), findsOneWidget);
    expect(find.text('Welcome, Dummy Seeker'), findsNothing);
    expect(
      MediaQuery.textScalerOf(
        tester.element(find.text('Welcome, Second Dummy')),
      ).scale(16),
      16,
    );
    await tester.pumpWidget(const SizedBox.shrink());
    await session.events.close();
  });
}
