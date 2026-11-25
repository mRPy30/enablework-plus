import '../models/seeker_workspace.dart';
import '../models/career_preview.dart';

class JobMatchResult {
  const JobMatchResult({
    required this.summary,
    this.skillsOnly = false,
    required this.matchedSkills,
    required this.skillGaps,
    required this.accessibilityConsiderations,
  });
  final bool skillsOnly;
  final String summary;
  factory JobMatchResult.compareSkills(JobListing job, List<String> skills) {
    String normalize(String text) =>
        text.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
    final saved = skills.map(normalize).where((s) => s.isNotEmpty).toSet();
    final required = job.requiredSkills.where((s) => s.trim().isNotEmpty);
    final matched = required
        .where((s) => saved.contains(normalize(s)))
        .toList();
    return JobMatchResult(
      skillsOnly: true,
      summary: required.isEmpty
          ? 'This posting lists no individual skills to compare. Read its qualifications in the job details.'
          : saved.isEmpty
          ? 'Add skills to your profile to compare them with this posting.'
          : 'Compared the skills listed for this job with the names of skills in your profile.',
      matchedSkills: matched,
      skillGaps: required.where((s) => !saved.contains(normalize(s))).toList(),
      accessibilityConsiderations: job.accessibility,
    );
  }
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
