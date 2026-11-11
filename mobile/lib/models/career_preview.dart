/// Presentation data for an explicitly offline seeker session.
class JobListing {
  const JobListing(
    this.id,
    this.title,
    this.company,
    this.city,
    this.arrangement,
    this.employment,
    this.description,
    this.accessibility,
  );
  final String id, title, company, city, arrangement, employment, description;
  final List<String> accessibility;

  bool matches(String search, String? work) {
    final words = search.toLowerCase().trim().split(RegExp(r'\s+'));
    final text = [
      title,
      company,
      city,
      ...accessibility,
    ].join(' ').toLowerCase();
    return (work == null || work == arrangement) && words.every(text.contains);
  }
}

class SeekerApplication {
  const SeekerApplication(this.job, this.resumeTitle, this.status, this.date);
  final JobListing job;
  final String resumeTitle, status;
  final DateTime date;
}

/// Never provided by the authenticated production workspace.
abstract interface class CareerPreview {
  List<JobListing> get jobs;
  Future<List<SeekerApplication>> applications();
  bool alreadyApplied(JobListing job);
  void savePreview(JobListing job, String resumeId);
}
