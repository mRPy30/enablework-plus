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
    double? textScale,
    bool? highContrast,
    bool? reduceMotion,
    List<String>? accessibilityNeeds,
    List<String>? enabledFeatures,
    bool? preferencesReviewed,
    String? updatedAt,
  }) : this._(
         textScale,
         highContrast,
         reduceMotion,
         accessibilityNeeds,
         enabledFeatures,
         preferencesReviewed,
         updatedAt,
       );

  const AccessibilityPreferences._(
    this._textScale,
    this._highContrast,
    this._reduceMotion,
    this._accessibilityNeeds,
    this._enabledFeatures,
    this._preferencesReviewed,
    this.updatedAt,
  );

  static const allowedNeeds = <String>{
    'visual',
    'mobility',
    'hearing',
    'speech',
    'intellectual',
    'learning',
    'psychosocial',
  };

  // Data identifiers scheduled for the later feature phase. No UI switch or
  // runtime capability is introduced by storing these choices in this phase.
  static const allowedFeatures = <String>{
    'voice_guidance',
    'text_to_speech',
    'voice_search',
    'simplified_language',
    'step_by_step_guidance',
  };

  final double? _textScale;
  final bool? _highContrast, _reduceMotion;
  double get textScale => _textScale ?? 1;
  bool get highContrast => _highContrast ?? false;
  bool get reduceMotion => _reduceMotion ?? false;
  final List<String>? _accessibilityNeeds, _enabledFeatures;
  final bool? _preferencesReviewed;
  final String? updatedAt;
  List<String> get accessibilityNeeds =>
      List.unmodifiable(_accessibilityNeeds ?? const <String>[]);
  List<String> get enabledFeatures =>
      List.unmodifiable(_enabledFeatures ?? const <String>[]);
  bool get preferencesReviewed => _preferencesReviewed ?? false;

  static List<String>? _selection(Map<String, dynamic> row, String key) {
    if (!row.containsKey(key)) return null; // Legacy three-column records.
    final value = row[key];
    if (value is! List || value.any((x) => x is! String)) {
      throw const WorkspaceFailure('Invalid accessibility selection.');
    }
    return List<String>.unmodifiable(value.cast<String>());
  }

  factory AccessibilityPreferences.fromJson(Map<String, dynamic> row) {
    if (row.containsKey('preferences_reviewed') &&
        row['preferences_reviewed'] is! bool) {
      throw const WorkspaceFailure('Invalid preference confirmation.');
    }
    final value = AccessibilityPreferences(
      textScale: (row['text_scale'] as num).toDouble(),
      highContrast: row['high_contrast'] as bool,
      reduceMotion: row['reduce_motion'] as bool,
      accessibilityNeeds: _selection(row, 'accessibility_needs'),
      enabledFeatures: _selection(row, 'enabled_features'),
      preferencesReviewed: row['preferences_reviewed'] as bool?,
      updatedAt: row['updated_at'] as String?,
    );
    value.validate();
    return value;
  }

  void validate() {
    if (!textScale.isFinite || textScale < 0.8 || textScale > 2) {
      throw const WorkspaceFailure('Choose a text size between 80% and 200%.');
    }
    for (final pair in [
      (accessibilityNeeds, allowedNeeds),
      (enabledFeatures, allowedFeatures),
    ]) {
      if (pair.$1.length > pair.$2.length ||
          pair.$1.toSet().length != pair.$1.length ||
          pair.$1.any((x) => !pair.$2.contains(x))) {
        throw const WorkspaceFailure(
          'Choose valid, unique accessibility options.',
        );
      }
    }
  }

  AccessibilityPreferences copyWith({
    double? textScale,
    bool? highContrast,
    bool? reduceMotion,
    List<String>? accessibilityNeeds,
    List<String>? enabledFeatures,
    bool? preferencesReviewed,
    String? updatedAt,
  }) => AccessibilityPreferences(
    textScale: textScale ?? this.textScale,
    highContrast: highContrast ?? this.highContrast,
    reduceMotion: reduceMotion ?? this.reduceMotion,
    accessibilityNeeds: List.unmodifiable(
      accessibilityNeeds ?? this.accessibilityNeeds,
    ),
    enabledFeatures: List.unmodifiable(enabledFeatures ?? this.enabledFeatures),
    preferencesReviewed: preferencesReviewed ?? this.preferencesReviewed,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  // A legacy three-field editor does not express an intent to clear new fields.
  // Explicit [] / false still means clear. The supplied version wins so stale
  // callers cannot silently acquire a newer version while keeping old values.
  AccessibilityPreferences mergeOnto(AccessibilityPreferences current) =>
      current.copyWith(
        textScale: _textScale,
        highContrast: _highContrast,
        reduceMotion: _reduceMotion,
        accessibilityNeeds: _accessibilityNeeds,
        enabledFeatures: _enabledFeatures,
        preferencesReviewed: _preferencesReviewed,
        updatedAt: updatedAt,
      );

  Map<String, dynamic> get updateJson => {
    if (_textScale != null)
      'text_scale': double.parse(textScale.toStringAsFixed(2)),
    if (_highContrast != null) 'high_contrast': highContrast,
    if (_reduceMotion != null) 'reduce_motion': reduceMotion,
    if (_accessibilityNeeds != null) 'accessibility_needs': accessibilityNeeds,
    if (_enabledFeatures != null) 'enabled_features': enabledFeatures,
    if (_preferencesReviewed != null)
      'preferences_reviewed': preferencesReviewed,
  };

  Map<String, dynamic> get json => {
    ...updateJson,
    'text_scale': double.parse(textScale.toStringAsFixed(2)),
    'high_contrast': highContrast,
    'reduce_motion': reduceMotion,
    'accessibility_needs': accessibilityNeeds,
    'enabled_features': enabledFeatures,
    'preferences_reviewed': preferencesReviewed,
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

class PickedImage {
  PickedImage(
    Uint8List bytes, {
    required this.extension,
    required this.contentType,
  }) : bytes = Uint8List.fromList(bytes) {
    validate();
  }
  static const maxBytes = 20 * 1024 * 1024;
  final Uint8List bytes;
  final String extension;
  final String contentType;
  void validate() {
    if (bytes.isEmpty || bytes.length > maxBytes) {
      throw const WorkspaceFailure('Choose an image no larger than 20 MB.');
    }
    const allowed = {'jpg', 'jpeg', 'png', 'webp'};
    if (!allowed.contains(extension.toLowerCase()) ||
        !{'image/jpeg', 'image/png', 'image/webp'}.contains(contentType)) {
      throw const WorkspaceFailure('Choose a JPEG, PNG, or WebP image.');
    }
  }
}

class ProfilePhoto {
  const ProfilePhoto({required this.url, required this.sizeBytes});
  final String url;
  final int sizeBytes;
}

class SeekerWorkspace {
  SeekerWorkspace({
    required this.profile,
    required this.preferences,
    required List<ResumeRecord> resumes,
    required Map<String, int> applicationCounts,
    this.profilePhoto,
  }) : resumes = List.unmodifiable(resumes),
       applicationCounts = Map.unmodifiable({
         for (final key in applicationStatusLabels.keys)
           key: applicationCounts[key] ?? 0,
       });
  final SeekerProfile profile;
  final AccessibilityPreferences preferences;
  final List<ResumeRecord> resumes;
  final Map<String, int> applicationCounts;
  final ProfilePhoto? profilePhoto;
  int get totalApplications =>
      applicationCounts.values.fold(0, (a, b) => a + b);
  ResumeRecord? get currentResume {
    for (final r in resumes) {
      if (r.isCurrent && r.status == ResumeStatus.ready) return r;
    }
    return null;
  }
}
