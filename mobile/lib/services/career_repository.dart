import '../models/career_preview.dart';
import '../models/seeker_workspace.dart';

/// Authenticated operations only; CareerPreview remains the offline contract.
abstract interface class CareerRepository {
  Future<List<JobListing>> loadJobs();
  Future<JobListing> loadJob(String id);
  Future<List<SeekerApplication>> loadApplications();
  Future<SeekerApplication?> findApplication(String jobId);
  Future<SeekerApplication> submitApplication(String jobId, String resumeId);
}

class SubmissionUncertain extends WorkspaceFailure {
  const SubmissionUncertain()
    : super(
        'Submission could not be confirmed. Check application status before trying again.',
      );
}
