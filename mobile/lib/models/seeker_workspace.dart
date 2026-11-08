import 'dart:typed_data';

class WorkspaceFailure implements Exception {
  const WorkspaceFailure(this.message, {this.accessLost = false});
  final String message;
  final bool accessLost;
}

const profileFieldLabels = <String, String>{
  'full_name': 'Full name',
  'phone': 'Phone (optional)',
  'headline': 'Professional headline',
  'city': 'City',
  'province': 'Province',
  'summary': 'About you',
  'education_summary': 'Education',
  'experience_summary': 'Work experience',
  'skills': 'Skills (separate with commas)',
  'accommodation_needs': 'Work adjustments (optional)',
};
const profileFieldLimits = <String, int>{
  'full_name': 120,
  'phone': 32,
  'headline': 180,
  'city': 120,
  'province': 120,
  'summary': 5000,
  'education_summary': 5000,
  'experience_summary': 5000,
  'skills': 12100,
  'accommodation_needs': 2000,
};
const jobTypeLabels = {
  'full_time': 'Full-time',
  'part_time': 'Part-time',
  'contract': 'Contract',
  'internship': 'Internship',
};
const workArrangementLabels = {
  'onsite': 'On-site',
  'remote': 'Remote',
  'hybrid': 'Hybrid',
};
const applicationStatusLabels = {
  'submitted': 'Submitted',
  'under_review': 'Under review',
  'shortlisted': 'Shortlisted',
  'rejected': 'Not selected',
  'hired': 'Hired',
};

List<String> parseSkills(String text) => text
    .split(',')
    .map((x) => x.trim())
    .where((x) => x.isNotEmpty)
    .toSet()
    .toList();
String? validateProfileField(String key, String value) {
  final text = value.trim();
  if (key == 'full_name' && text.isEmpty) return 'Enter your name.';
  if (text.length > (profileFieldLimits[key] ?? 0)) {
    return 'Please shorten this field.';
  }
  if (key == 'phone' &&
      text.isNotEmpty &&
      (!RegExp(r'^[+0-9() .-]{7,32}$').hasMatch(text) ||
          RegExp(r'[0-9]').allMatches(text).length < 7)) {
    return 'Enter a valid phone number, or leave it empty.';
  }
  if (key == 'skills') {
    final values = parseSkills(text);
    if (values.length > 100 || values.any((x) => x.length > 120)) {
      return 'Use up to 100 skills, each no longer than 120 characters.';
    }
  }
  return null;
}

class SeekerProfile {
  SeekerProfile({
    required this.userId,
    required this.updatedAt,
    required Map<String, String> fields,
    List<String> jobTypes = const [],
    List<String> workArrangements = const [],
  }) : fields = Map.unmodifiable({
         for (final key in profileFieldLabels.keys) key: fields[key] ?? '',
       }),
       jobTypes = List.unmodifiable(jobTypes),
       workArrangements = List.unmodifiable(workArrangements);
  final String userId, updatedAt;
  final Map<String, String> fields;
  final List<String> jobTypes, workArrangements;
  factory SeekerProfile.fromJson(Map<String, dynamic> value) {
    final p = Map<String, dynamic>.from(value['profile'] as Map);
    final s = Map<String, dynamic>.from(value['details'] as Map);
    if (p['id'] != s['user_id']) {
      throw const WorkspaceFailure(
        'Profile unavailable. Please sign in again.',
        accessLost: true,
      );
    }
    return SeekerProfile(
      userId: p['id'] as String,
      updatedAt: p['updated_at'] as String,
      fields: {
        for (final key in profileFieldLabels.keys)
          key: key == 'skills'
              ? List<String>.from(s[key] as List? ?? []).join(', ')
              : (key == 'full_name' || key == 'phone' ? p[key] : s[key])
                        as String? ??
                    '',
      },
      jobTypes: List<String>.from(s['preferred_job_types'] as List? ?? []),
      workArrangements: List<String>.from(
        s['preferred_work_arrangements'] as List? ?? [],
      ),
    );
  }
  Map<String, dynamic> get identityJson => {
    'full_name': fields['full_name']!.trim(),
    'phone': fields['phone']!.trim(),
  };
  Map<String, dynamic> get detailsJson => {
    for (final key in profileFieldLabels.keys)
      if (key != 'full_name' && key != 'phone' && key != 'skills')
        key: fields[key]!.trim(),
    'skills': parseSkills(fields['skills']!),
    'preferred_job_types': jobTypes,
    'preferred_work_arrangements': workArrangements,
  };
  void validate() {
    for (final e in fields.entries) {
      final error = validateProfileField(e.key, e.value);
      if (error != null) throw WorkspaceFailure(error);
    }
    if (jobTypes.any((x) => !jobTypeLabels.containsKey(x)) ||
        workArrangements.any((x) => !workArrangementLabels.containsKey(x))) {
      throw const WorkspaceFailure('Choose a supported work preference.');
    }
  }

  int get completionPercent {
    final complete = [
      fields['full_name']!.trim().isNotEmpty,
      fields['headline']!.trim().isNotEmpty,
      fields['summary']!.trim().isNotEmpty,
      parseSkills(fields['skills']!).isNotEmpty,
      fields['education_summary']!.trim().isNotEmpty ||
          fields['experience_summary']!.trim().isNotEmpty,
      fields['city']!.trim().isNotEmpty ||
          fields['province']!.trim().isNotEmpty,
    ].where((x) => x).length;
    return (complete * 100 / 6).round();
  }
}

class AccessibilityPreferences {
  const AccessibilityPreferences({
    this.textScale = 1,
    this.highContrast = false,
    this.reduceMotion = false,
  });
  final double textScale;
  final bool highContrast, reduceMotion;
  factory AccessibilityPreferences.fromJson(Map<String, dynamic> row) {
    final value = AccessibilityPreferences(
      textScale: (row['text_scale'] as num).toDouble(),
      highContrast: row['high_contrast'] as bool,
      reduceMotion: row['reduce_motion'] as bool,
    );
    value.validate();
    return value;
  }
  void validate() {
    if (!textScale.isFinite || textScale < 0.8 || textScale > 2) {
      throw const WorkspaceFailure('Choose a text size between 80% and 200%.');
    }
  }

  Map<String, dynamic> get json => {
    'text_scale': double.parse(textScale.toStringAsFixed(2)),
    'high_contrast': highContrast,
    'reduce_motion': reduceMotion,
  };
}

enum ResumeStatus { pending, ready, failed, deleting }

class ResumeRecord {
  const ResumeRecord({
    required this.id,
    required this.title,
    required this.status,
    this.isCurrent = false,
    this.isSubmitted = false,
    this.sizeBytes,
  });
  final String id, title;
  final ResumeStatus status;
  final bool isCurrent, isSubmitted;
  final int? sizeBytes;
  factory ResumeRecord.fromJson(Map<String, dynamic> row) => ResumeRecord(
    id: row['id'] as String,
    title: row['title'] as String,
    status: ResumeStatus.values.byName(row['upload_status'] as String),
    isCurrent: row['is_current'] as bool? ?? false,
    isSubmitted: (row['applications'] as List? ?? []).isNotEmpty,
    sizeBytes: (row['size_bytes'] as num?)?.toInt(),
  );
  bool get canSelect => status == ResumeStatus.ready;
  bool get canRemove => !isSubmitted;
  String get statusLabel => switch (status) {
    ResumeStatus.pending => 'Awaiting validation',
    ResumeStatus.ready => 'Available',
    ResumeStatus.failed => 'Upload incomplete',
    ResumeStatus.deleting => 'Removal in progress',
  };
}

class PickedPdf {
  PickedPdf(Uint8List bytes) : bytes = Uint8List.fromList(bytes) {
    validate();
  }
  static const maxBytes = 5 * 1024 * 1024;
  final Uint8List bytes;
  void validate() {
    if (bytes.length > maxBytes) {
      throw const WorkspaceFailure('Choose a PDF no larger than 5 MiB.');
    }
    if (bytes.length < 5 || String.fromCharCodes(bytes.take(5)) != '%PDF-') {
      throw const WorkspaceFailure('Choose a PDF document.');
    }
  }

  static Future<PickedPdf> read(
    Stream<List<int>> stream, {
    required String name,
    int? declaredSize,
  }) async {
    if (!name.toLowerCase().endsWith('.pdf')) {
      throw const WorkspaceFailure('Choose a PDF document.');
    }
    if (declaredSize != null && declaredSize > maxBytes) {
      throw const WorkspaceFailure('Choose a PDF no larger than 5 MiB.');
    }
    final builder = BytesBuilder(copy: false);
    var length = 0;
    await for (final chunk in stream) {
      length += chunk.length;
      if (length > maxBytes) {
        throw const WorkspaceFailure('Choose a PDF no larger than 5 MiB.');
      }
      builder.add(chunk);
    }
    return PickedPdf(builder.takeBytes());
  }
}

class SeekerWorkspace {
  SeekerWorkspace({
    required this.profile,
    required this.preferences,
    required List<ResumeRecord> resumes,
    required Map<String, int> applicationCounts,
  }) : resumes = List.unmodifiable(resumes),
       applicationCounts = Map.unmodifiable({
         for (final key in applicationStatusLabels.keys)
           key: applicationCounts[key] ?? 0,
       });
  final SeekerProfile profile;
  final AccessibilityPreferences preferences;
  final List<ResumeRecord> resumes;
  final Map<String, int> applicationCounts;
  int get totalApplications =>
      applicationCounts.values.fold(0, (a, b) => a + b);
  ResumeRecord? get currentResume {
    for (final r in resumes) {
      if (r.isCurrent && r.status == ResumeStatus.ready) return r;
    }
    return null;
  }
}
