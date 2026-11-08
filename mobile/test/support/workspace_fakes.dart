import 'dart:async';
import 'dart:typed_data';

import 'package:enablework_plus/models/seeker_workspace.dart';
import 'package:enablework_plus/services/seeker_repository.dart';

SeekerProfile dummyProfile({String version = '2026-11-08T00:00:00Z'}) =>
    SeekerProfile(
      userId: 'dummy-a',
      updatedAt: version,
      fields: {
        'full_name': 'Dummy Seeker',
        'headline': 'Customer service trainee',
        'summary': 'Synthetic test profile only.',
        'city': 'Dummy City',
        'education_summary': 'Dummy training',
        'skills': 'Communication, Testing',
      },
    );
SeekerWorkspace dummyWorkspace({
  List<ResumeRecord> resumes = const [],
  AccessibilityPreferences preferences = const AccessibilityPreferences(),
}) => SeekerWorkspace(
  profile: dummyProfile(),
  preferences: preferences,
  resumes: resumes,
  applicationCounts: {'submitted': 2, 'shortlisted': 1},
);

class FakeRepository implements SeekerRepository {
  @override
  String get userId => 'dummy-a';
  SeekerWorkspace value = dummyWorkspace();
  Object? fail;
  int saves = 0, uploads = 0, removals = 0;
  Completer<SeekerWorkspace>? pendingLoad;
  @override
  Future<SeekerWorkspace> load() async {
    if (fail != null) throw fail!;
    return pendingLoad == null ? value : pendingLoad!.future;
  }

  @override
  Future<void> saveProfile(SeekerProfile profile) async {
    profile.validate();
    if (fail != null) throw fail!;
    saves++;
    value = SeekerWorkspace(
      profile: profile,
      preferences: value.preferences,
      resumes: value.resumes,
      applicationCounts: value.applicationCounts,
    );
  }

  @override
  Future<void> savePreferences(AccessibilityPreferences preferences) async {
    preferences.validate();
    if (fail != null) throw fail!;
    value = SeekerWorkspace(
      profile: value.profile,
      preferences: preferences,
      resumes: value.resumes,
      applicationCounts: value.applicationCounts,
    );
  }

  @override
  Future<void> upload(
    String title,
    PickedPdf pdf,
    void Function(String) progress,
  ) async {
    pdf.validate();
    if (fail != null) throw fail!;
    uploads++;
    progress('Validating your PDF');
    value = dummyWorkspace(
      resumes: [
        ResumeRecord(
          id: 'dummy-resume',
          title: title,
          status: ResumeStatus.ready,
        ),
      ],
    );
  }

  @override
  Future<void> retryValidation(String id) async {
    if (fail != null) throw fail!;
  }

  @override
  Future<void> setCurrent(String id) async {
    if (fail != null) throw fail!;
  }

  @override
  Future<void> remove(String id) async {
    if (fail != null) throw fail!;
    removals++;
    value = dummyWorkspace();
  }
}

class FakePicker implements PdfPicker {
  FakePicker(this.value);
  final PickedPdf? value;
  @override
  Future<PickedPdf?> pick() async => value;
}

PickedPdf dummyPdf() =>
    PickedPdf(Uint8List.fromList('%PDF-1.4 TEST DATA ONLY'.codeUnits));
