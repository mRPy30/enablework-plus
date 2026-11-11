import 'package:flutter/foundation.dart';

import '../models/seeker_workspace.dart';
import '../services/seeker_repository.dart';

class SeekerController extends ChangeNotifier {
  SeekerController(
    this.repository, {
    required this.onPreferences,
    required this.onAccessLost,
  });
  final SeekerRepository repository;
  final void Function(AccessibilityPreferences) onPreferences;
  final VoidCallback onAccessLost;
  SeekerWorkspace? data;
  String? error;
  String progress = '';
  bool loading = false, busy = false;
  bool _disposed = false;
  int _generation = 0;
  bool _current(int token) => !_disposed && token == _generation;
  void clearError() {
    error = null;
    notifyListeners();
  }

  void _failure(Object failure) {
    final value = failure is WorkspaceFailure
        ? failure
        : const WorkspaceFailure(
            'Unable to complete the request. Please try again.',
          );
    error = value.message;
    if (value.accessLost) {
      data = null;
      loading = false;
      _generation++;
      onAccessLost();
    }
  }

  Future<void> load() async {
    if (busy || _disposed) return;
    final token = ++_generation;
    loading = true;
    error = null;
    notifyListeners();
    try {
      final result = await repository.load();
      if (_current(token)) {
        data = result;
        onPreferences(result.preferences);
      }
    } catch (e) {
      if (_current(token)) _failure(e);
    } finally {
      if (_current(token)) {
        loading = false;
        notifyListeners();
      }
    }
  }

  Future<bool> _mutate(
    Future<void> Function() action, {
    String label = 'Saving',
  }) async {
    if (busy || loading || _disposed || data == null) return false;
    final token = _generation;
    busy = true;
    error = null;
    progress = label;
    notifyListeners();
    try {
      await action();
      if (!_current(token)) return false;
      final result = await repository.load();
      if (!_current(token)) return false;
      data = result;
      onPreferences(result.preferences);
      return true;
    } catch (e) {
      if (_current(token)) {
        _failure(e);
        // Refresh after uncertain file outcomes, preserving the original useful error.
        if (e is! WorkspaceFailure || !e.accessLost) {
          try {
            final result = await repository.load();
            if (_current(token)) {
              data = result;
              onPreferences(result.preferences);
            }
          } catch (refreshError) {
            if (_current(token) &&
                refreshError is WorkspaceFailure &&
                refreshError.accessLost) {
              _failure(refreshError);
            }
          }
        }
      }
      return false;
    } finally {
      if (!_disposed) {
        busy = false;
        progress = '';
        notifyListeners();
      }
    }
  }

  Future<bool> saveProfile(SeekerProfile value) =>
      _mutate(() => repository.saveProfile(value));
  Future<bool> savePreferences(AccessibilityPreferences value) {
    if (data == null) return Future.value(false);
    final merged = value.mergeOnto(data!.preferences);
    return _mutate(() => repository.savePreferences(merged));
  }

  Future<bool> upload(String title, PickedPdf pdf) => _mutate(
    () => repository.upload(title, pdf, (value) {
      if (!_disposed) {
        progress = value;
        notifyListeners();
      }
    }),
    label: 'Preparing your PDF',
  );
  Future<bool> retryValidation(String id) => _mutate(
    () => repository.retryValidation(id),
    label: 'Validating your PDF',
  );
  Future<bool> setCurrent(String id) =>
      _mutate(() => repository.setCurrent(id));
  Future<bool> remove(String id) =>
      _mutate(() => repository.remove(id), label: 'Removing your resume');
  @override
  void dispose() {
    _disposed = true;
    _generation++;
    data = null;
    super.dispose();
  }
}
