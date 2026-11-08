enum AppRole { jobSeeker, systemAdministrator }

class AccountProfile {
  const AccountProfile(this.role);
  final AppRole role;

  factory AccountProfile.fromJson(Map<String, dynamic> value) {
    if (value['account_status'] != 'active') {
      throw StateError('Account unavailable');
    }
    final role = switch (value['role']) {
      'job_seeker' => AppRole.jobSeeker,
      'system_administrator' => AppRole.systemAdministrator,
      _ => throw StateError('Account unavailable'),
    };
    return AccountProfile(role);
  }
}
