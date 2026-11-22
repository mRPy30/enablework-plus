import 'auth_service.dart';

/// Uses the signed-in administrator session; database RLS remains authoritative.
abstract interface class AdminDataSource {
  Future<Map<String, int>> counts();
  Future<List<Map<String, dynamic>>> records(String section, int page);
}

class AdminRepository implements AdminDataSource {
  AdminRepository(this.auth);
  final AuthService auth;

  Future<Map<String, int>> counts() async {
    await auth.requireAccess();
    final client = auth.client;
    final counts = await Future.wait([
      client.from('profiles').count().eq('role', 'job_seeker'),
      client.from('employers').count().eq('is_active', true),
      client.from('jobs').count().eq('status', 'published'),
      client.from('applications').count(),
    ]).timeout(const Duration(seconds: 20));
    return Map.fromIterables([
      'PWD job seekers',
      'Active companies',
      'Published jobs',
      'Applications',
    ], counts);
  }

  Future<List<Map<String, dynamic>>> records(String section, int page) async {
    await auth.requireAccess();
    final client = auth.client;
    final start = page * 25;
    final query = switch (section) {
      'seekers' =>
        client
            .from('profiles')
            .select('id,full_name,account_status,created_at')
            .eq('role', 'job_seeker')
            .order('created_at', ascending: false)
            .order('id')
            .range(start, start + 24),
      'companies' =>
        client
            .from('employers')
            .select('id,company_name,city,province,is_active')
            .order('company_name')
            .order('id')
            .range(start, start + 24),
      'jobs' =>
        client
            .from('jobs')
            .select(
              'id,title,status,employment_type,work_arrangement,employers(company_name)',
            )
            .order('created_at', ascending: false)
            .order('id')
            .range(start, start + 24),
      'applications' =>
        client
            .from('applications')
            .select(
              'id,status,submitted_at,jobs(title),job_seeker_profiles(profiles(full_name))',
            )
            .order('submitted_at', ascending: false)
            .order('id')
            .range(start, start + 24),
      _ => throw ArgumentError('Unsupported administrator section'),
    };
    return await query.timeout(const Duration(seconds: 20));
  }
}
