import 'package:file_picker/file_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/seeker_workspace.dart';
import 'auth_service.dart';

abstract interface class PdfPicker {
  Future<PickedPdf?> pick();
}

class DevicePdfPicker implements PdfPicker {
  @override
  Future<PickedPdf?> pick() async {
    final file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );
    if (file == null) return null;
    return PickedPdf.read(
      file.readAsByteStream(),
      name: file.name,
      declaredSize: await file.length(),
    );
  }
}

abstract interface class ResumeBackend {
  Future<String> beginUpload(String title);
  Future<void> putPdf(String id, PickedPdf file);
  Future<void> finalize(String id);
  Future<void> remove(String id);
}

class ResumeLifecycle {
  ResumeLifecycle(this.backend);
  final ResumeBackend backend;
  Future<void> upload(
    String title,
    PickedPdf file,
    void Function(String) progress,
  ) async {
    file.validate();
    if (title.trim().isEmpty || title.trim().length > 180) {
      throw const WorkspaceFailure(
        'Enter a resume title of up to 180 characters.',
      );
    }
    progress('Preparing your upload');
    final id = await backend.beginUpload(title.trim());
    progress('Uploading your PDF');
    await backend.putPdf(id, file);
    progress('Validating your PDF');
    await backend.finalize(id);
    // On failure retain the pending record; a timeout may have completed server-side.
    // The list offers retry validation/removal. Never overwrite or silently delete.
  }
}

abstract interface class SeekerRepository {
  String get userId;
  Future<SeekerWorkspace> load();
  Future<void> saveProfile(SeekerProfile profile);
  Future<void> savePreferences(AccessibilityPreferences preferences);
  Future<void> upload(
    String title,
    PickedPdf file,
    void Function(String) progress,
  );
  Future<void> retryValidation(String id);
  Future<void> setCurrent(String id);
  Future<void> remove(String id);
}

class SupabaseSeekerRepository implements SeekerRepository, ResumeBackend {
  SupabaseSeekerRepository(this.auth, this.userId);
  final AuthService auth;
  SupabaseClient get _client => auth.client;
  @override
  final String userId;
  final Map<String, String> _uploadPaths = {};

  Future<void> _guard() async {
    if (auth.userId != userId) {
      throw const WorkspaceFailure(
        'Your session changed. Please sign in again.',
        accessLost: true,
      );
    }
    try {
      await auth.requireAccess();
    } on StateError {
      throw const WorkspaceFailure(
        'Your account access changed. Please sign in again.',
        accessLost: true,
      );
    }
    if (auth.userId != userId) {
      throw const WorkspaceFailure(
        'Your session changed. Please sign in again.',
        accessLost: true,
      );
    }
  }

  Future<T> _run<T>(Future<T> Function() operation) async {
    try {
      await _guard();
      final result = await operation();
      if (auth.userId != userId) {
        throw const WorkspaceFailure('Please sign in again.', accessLost: true);
      }
      return result;
    } on WorkspaceFailure {
      rethrow;
    } on AuthException {
      throw const WorkspaceFailure('Please sign in again.', accessLost: true);
    } on PostgrestException catch (e) {
      if (['42501', 'PGRST301', 'PGRST302'].contains(e.code)) {
        throw const WorkspaceFailure(
          'Your account access changed. Please sign in again.',
          accessLost: true,
        );
      }
      if (e.code == '40001') {
        throw const WorkspaceFailure(
          'Your profile changed elsewhere. Reload it before saving.',
        );
      }
      if (e.code == '23503') {
        throw const WorkspaceFailure('A submitted resume must be retained.');
      }
      throw const WorkspaceFailure(
        'Unable to save or load your information. Please try again.',
      );
    } on StorageException catch (e) {
      if (['401', '403'].contains(e.statusCode.toString())) {
        throw const WorkspaceFailure('Please sign in again.', accessLost: true);
      }
      throw const WorkspaceFailure(
        'The file operation could not finish. Refresh and try again.',
      );
    } on FunctionException catch (e) {
      if (e.status == 401 || e.status == 403) {
        throw const WorkspaceFailure('Please sign in again.', accessLost: true);
      }
      throw const WorkspaceFailure(
        'PDF validation could not finish. Refresh to retry validation or remove the incomplete upload.',
      );
    } catch (_) {
      throw const WorkspaceFailure('Connection unavailable. Please try again.');
    }
  }

  @override
  Future<SeekerWorkspace> load() => _run(() async {
    final values = await Future.wait<dynamic>([
      _client.rpc('my_job_seeker_profile'),
      _client
          .from('accessibility_preferences')
          .select('text_scale,high_contrast,reduce_motion')
          .eq('user_id', userId)
          .single(),
      _listResumes(),
      _client.rpc('my_application_counts'),
    ]);
    final profile = SeekerProfile.fromJson(
      Map<String, dynamic>.from(values[0] as Map),
    );
    if (profile.userId != userId) {
      throw const WorkspaceFailure('Please sign in again.', accessLost: true);
    }
    final counts = <String, int>{};
    for (final item in values[3] as List) {
      final status = item['status'] as String;
      final total = (item['total'] as num).toInt();
      if (!applicationStatusLabels.containsKey(status) || total < 0) {
        throw const WorkspaceFailure('Application summary unavailable.');
      }
      counts[status] = total;
    }
    return SeekerWorkspace(
      profile: profile,
      preferences: AccessibilityPreferences.fromJson(
        Map<String, dynamic>.from(values[1] as Map),
      ),
      resumes: values[2] as List<ResumeRecord>,
      applicationCounts: counts,
    );
  });
  Future<List<ResumeRecord>> _listResumes() async {
    final result = <ResumeRecord>[];
    for (var offset = 0; ; offset += 100) {
      await _guard();
      final rows = await _client
          .from('resumes')
          .select(
            'id,title,upload_status,size_bytes,is_current,created_at,applications(id)',
          )
          .eq('job_seeker_id', userId)
          .order('created_at', ascending: false)
          .order('id')
          .limit(1, referencedTable: 'applications')
          .range(offset, offset + 99);
      result.addAll(rows.map(ResumeRecord.fromJson));
      if (rows.length < 100) break;
    }
    return result;
  }

  @override
  Future<void> saveProfile(SeekerProfile profile) => _run(() async {
    profile.validate();
    if (profile.userId != userId) {
      throw const WorkspaceFailure('Please sign in again.', accessLost: true);
    }
    await _client.rpc(
      'save_my_job_seeker_profile',
      params: {
        'p_profile': profile.identityJson,
        'p_details': profile.detailsJson,
        'p_expected_updated_at': profile.updatedAt,
      },
    );
  });
  @override
  Future<void> savePreferences(AccessibilityPreferences preferences) =>
      _run(() async {
        preferences.validate();
        await _client
            .from('accessibility_preferences')
            .update(preferences.json)
            .eq('user_id', userId)
            .select('user_id')
            .single();
      });
  @override
  Future<void> upload(
    String title,
    PickedPdf file,
    void Function(String) progress,
  ) => ResumeLifecycle(this).upload(title, file, progress);
  @override
  Future<String> beginUpload(String title) => _run(() async {
    final value = await _client.rpc(
      'begin_resume_upload',
      params: {'p_title': title},
    );
    final row = Map<String, dynamic>.from(
      value is List ? value.single as Map : value as Map,
    );
    if (row['job_seeker_id'] != userId) {
      throw const WorkspaceFailure('Please sign in again.', accessLost: true);
    }
    final id = row['id'] as String;
    _uploadPaths[id] = row['storage_path'] as String;
    return id;
  });
  @override
  Future<void> putPdf(String id, PickedPdf file) => _run(() async {
    file.validate();
    final path = _uploadPaths[id];
    if (path == null) throw const WorkspaceFailure('Start a new upload.');
    await _client.storage
        .from('resumes')
        .uploadBinary(
          path,
          file.bytes,
          fileOptions: const FileOptions(
            contentType: 'application/pdf',
            upsert: false,
            cacheControl: '0',
          ),
        );
    _uploadPaths.remove(id);
  });
  @override
  Future<void> finalize(String id) => _run(() async {
    final response = await _client.functions.invoke(
      'resume-finalize',
      body: {'resume_id': id},
    );
    if (response.status != 200) {
      throw const WorkspaceFailure(
        'PDF validation could not finish. Try again from the resume list.',
      );
    }
  });
  @override
  Future<void> retryValidation(String id) => finalize(id);
  @override
  Future<void> setCurrent(String id) => _run(() async {
    await _client.rpc('set_current_resume', params: {'p_resume_id': id});
  });
  @override
  Future<void> remove(String id) => _run(() async {
    final path = await _client.rpc(
      'begin_resume_deletion',
      params: {'p_resume_id': id},
    ) as String;
    await _guard();
    await _client.storage.from('resumes').remove([path]);
    await _guard();
    await _client.rpc('complete_resume_deletion', params: {'p_resume_id': id});
    _uploadPaths.remove(id);
  });
}
