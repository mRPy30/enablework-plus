import '../models/seeker_workspace.dart';

class ResumeScanResult {
  const ResumeScanResult({
    required this.strengths,
    required this.missingSections,
    required this.skills,
    required this.readabilityNotes,
    required this.accessibilityNotes,
  });
  final List<String> strengths;
  final List<String> missingSections;
  final List<String> skills;
  final List<String> readabilityNotes;
  final List<String> accessibilityNotes;

  factory ResumeScanResult.fromJson(Map<String, dynamic> json) {
    List<String> values(String key) => (json[key] as List? ?? [])
        .whereType<String>()
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toList(growable: false);
    return ResumeScanResult(
      strengths: values('strengths'),
      missingSections: values('missing_sections'),
      skills: values('skills'),
      readabilityNotes: values('readability_notes'),
      accessibilityNotes: values('accessibility_notes'),
    );
  }
}

abstract interface class ResumeScanRepository {
  Future<ResumeScanResult> scanResume(String resumeId);
}

WorkspaceFailure resumeScanFailure(Object error) {
  if (error is WorkspaceFailure) return error;
  return const WorkspaceFailure(
    'Resume scanning is unavailable right now. Please try again later.',
  );
}
