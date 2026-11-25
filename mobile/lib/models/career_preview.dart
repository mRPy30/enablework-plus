/// Shared presentation data. Offline records remain in the demo repository.
class JobListing {
  const JobListing(
    this.id,
    this.title,
    this.company,
    this.city,
    this.arrangement,
    this.employment,
    this.description,
    this.accessibility, {
    this.qualifications = '',
    this.requiredSkills = const [],
    this.acceptingApplications = true,
    this.deadline,
  });
  final String id, title, company, city, arrangement, employment, description;
  final List<String> accessibility;
  final String qualifications;
  final List<String> requiredSkills;
  final bool acceptingApplications;
  final DateTime? deadline;

  bool matches(String search, String? work) {
    final words = search.toLowerCase().trim().split(RegExp(r'\s+'));
    final text = [
      title,
      company,
      city,
      ...requiredSkills,
      ...accessibility,
    ].join(' ').toLowerCase();
    return (work == null || work == arrangement) && words.every(text.contains);
  }
}

class SeekerApplication {
  const SeekerApplication(
    this.job,
    this.resumeTitle,
    this.status,
    this.date, {
    this.id,
    this.resumeId,
  });
  final JobListing job;
  final String resumeTitle, status;
  final DateTime date;
  final String? id, resumeId;
}

/// Never provided by the authenticated production workspace.
abstract interface class CareerPreview {
  List<JobListing> get jobs;
  Future<List<SeekerApplication>> applications();
  bool alreadyApplied(JobListing job);
  void savePreview(JobListing job, String resumeId);
}
