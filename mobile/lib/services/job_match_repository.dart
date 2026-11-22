import '../models/seeker_workspace.dart';

class JobMatchResult {
  const JobMatchResult({
    required this.summary,
    required this.matchedSkills,
    required this.skillGaps,
    required this.accessibilityConsiderations,
  });
  final String summary;
  final List<String> matchedSkills, skillGaps, accessibilityConsiderations;
  factory JobMatchResult.fromJson(Map<String, dynamic> json) {
    List<String> list(String key) =>
        (json[key] as List? ?? []).whereType<String>().toList(growable: false);
    return JobMatchResult(
      summary: json['fit_summary'] as String? ?? 'No summary was returned.',
      matchedSkills: list('matched_skills'),
      skillGaps: list('skill_gaps'),
      accessibilityConsiderations: list('accessibility_considerations'),
    );
  }
}

abstract interface class JobMatchRepository {
  Future<JobMatchResult> matchJob(String jobId);
}

WorkspaceFailure jobMatchFailure(Object error) => error is WorkspaceFailure
    ? error
    : const WorkspaceFailure(
        'Job matching is unavailable right now. Please try again later.',
      );
