import 'package:enablework_plus/models/career_preview.dart';
import 'package:enablework_plus/services/job_match_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const job = JobListing(
    '1',
    'Assistant',
    'Office',
    'Manila',
    'onsite',
    'full_time',
    '',
    ['Ramp'],
    requiredSkills: ['Data entry', 'Excel'],
  );
  test('skills comparison uses stated skills and employer accessibility', () {
    final result = JobMatchResult.compareSkills(job, ['  DATA   entry ']);
    expect(result.skillsOnly, isTrue);
    expect(result.matchedSkills, ['Data entry']);
    expect(result.skillGaps, ['Excel']);
    expect(result.accessibilityConsiderations, ['Ramp']);
  });
  test('empty skills prompt for profile information', () {
    expect(
      JobMatchResult.compareSkills(job, []).summary,
      contains('Add skills'),
    );
  });
  test('AI response retains its own result type', () {
    expect(
      JobMatchResult.fromJson({'fit_summary': 'Example'}).skillsOnly,
      isFalse,
    );
  });
}
