import '../models/career_preview.dart';
import '../models/seeker_workspace.dart';
import '../services/seeker_repository.dart';

/// Fictional session owned by the demo entry point. No disk or network access.
class DemoWorkspace implements SeekerRepository, CareerPreview {
  @override
  String get userId => 'demo-seeker';

  @override
  final jobs = const [
    JobListing(
      'filinvest-support',
      '[DEMO DATA] Customer support associate',
      'Filinvest-area Demo Employer',
      'Muntinlupa / remote',
      'hybrid',
      'full_time',
      'Demo posting for client presentation only. Respond to customer questions through email and chat, document requests, and coordinate accessible service support.',
      [
        'Step-free entrance',
        'Chat-based communication',
        'Captioned team meetings',
      ],
    ),
    JobListing(
      'concentrix-qa',
      '[DEMO DATA] Quality assurance assistant',
      'Alabang Demo Contact Center',
      'Alabang, Muntinlupa',
      'remote',
      'full_time',
      'Demo posting for client presentation only. Review support records, document quality findings, and prepare clear written feedback for a remote team.',
      ['Written task instructions', 'Flexible break scheduling', 'Remote-first setup'],
    ),
    JobListing(
      'filinvest-records',
      '[DEMO DATA] Records and data assistant',
      'Filinvest-area Demo Employer',
      'Filinvest City, Muntinlupa',
      'onsite',
      'full_time',
      'Demo posting for client presentation only. Organize digital records, check data quality, and maintain an accessible document register.',
      ['Step-free entrance', 'Accessible restroom', 'Adjustable workstation'],
    ),
    JobListing(
      'alabang-web',
      '[DEMO DATA] Junior web support specialist',
      'Alabang Technology Demo Employer',
      'Muntinlupa / hybrid',
      'hybrid',
      'part_time',
      'Demo posting for client presentation only. Help maintain accessible web content, reproduce issues, and write clear support notes for the product team.',
      ['Keyboard-friendly tools', 'Written communication', 'Flexible schedule'],
    ),
    JobListing(
      'muntinlupa-admin',
      '[DEMO DATA] Administrative coordinator',
      'Muntinlupa Business Demo Employer',
      'Muntinlupa',
      'onsite',
      'full_time',
      'Demo posting for client presentation only. Coordinate calendars, prepare documents, and support an inclusive office operations team.',
      ['Step-free entrance', 'Accessible restroom', 'Quiet workspace option'],
    ),
  ];
  final _applications = <SeekerApplication>[];
  var _profile = SeekerProfile(
    userId: 'demo-seeker',
    updatedAt: '0',
    fields: {
      'full_name': 'Alex Reyes',
      'headline': 'Office support trainee',
      'skills': 'Cataloging, data entry',
      'city': 'Quezon City',
    },
  );
  var _preferences = const AccessibilityPreferences(preferencesReviewed: true);
  final _resumes = <ResumeRecord>[
    const ResumeRecord(
      id: 'sample',
      title: 'Office support resume',
      status: ResumeStatus.ready,
      isCurrent: true,
    ),
  ];
  var _sequence = 0;
  @override
  Future<void> uploadProfilePhoto(PickedImage image) async {
    throw const WorkspaceFailure('Profile photos are unavailable in this preview.');
  }
  @override
  Future<SeekerWorkspace> load() async => SeekerWorkspace(
    profile: _profile,
    preferences: _preferences,
    resumes: _resumes,
    applicationCounts: {'submitted': _applications.length},
  );
  @override
  Future<void> saveProfile(SeekerProfile profile) async {
    profile.validate();
    _profile = SeekerProfile(
      userId: userId,
      updatedAt: (++_sequence).toString(),
      fields: profile.fields,
      jobTypes: profile.jobTypes,
      workArrangements: profile.workArrangements,
    );
  }

  @override
  Future<void> savePreferences(AccessibilityPreferences preferences) async {
    preferences.validate();
    _preferences = preferences.copyWith(updatedAt: (++_sequence).toString());
  }

  @override
  Future<void> upload(
    String title,
    PickedPdf pdf,
    void Function(String) progress,
  ) async {
    throw const WorkspaceFailure(
      'Personal files cannot be uploaded in this preview.',
    );
  }

  @override
  Future<void> retryValidation(String id) async {
    throw const WorkspaceFailure(
      'File validation is unavailable in this preview.',
    );
  }

  void addSample() {
    _resumes.add(
      ResumeRecord(
        id: 'sample-${++_sequence}',
        title: 'Sample resume $_sequence',
        status: ResumeStatus.ready,
      ),
    );
  }

  ResumeRecord _withFlags(
    ResumeRecord record, {
    bool? current,
    bool? submitted,
  }) => ResumeRecord(
    id: record.id,
    title: record.title,
    status: record.status,
    isCurrent: current ?? record.isCurrent,
    isSubmitted: submitted ?? record.isSubmitted,
  );
  @override
  Future<void> setCurrent(String id) async {
    if (!_resumes.any((r) => r.id == id && r.canSelect)) return;
    for (var i = 0; i < _resumes.length; i++) {
      _resumes[i] = _withFlags(_resumes[i], current: _resumes[i].id == id);
    }
  }

  @override
  Future<void> remove(String id) async =>
      _resumes.removeWhere((r) => r.id == id && r.canRemove);

  @override
  Future<List<SeekerApplication>> applications() async =>
      List.unmodifiable(_applications);
  @override
  bool alreadyApplied(JobListing job) =>
      _applications.any((a) => a.job.id == job.id);
  @override
  void savePreview(JobListing job, String resumeId) {
    final index = _resumes.indexWhere((r) => r.id == resumeId && r.canSelect);
    if (index < 0 || alreadyApplied(job)) {
      throw const WorkspaceFailure('Check the selected job and resume.');
    }
    final r = _resumes[index];
    _applications.insert(
      0,
      SeekerApplication(job, r.title, 'submitted', DateTime.now()),
    );
    _resumes[index] = _withFlags(r, submitted: true);
  }
}
