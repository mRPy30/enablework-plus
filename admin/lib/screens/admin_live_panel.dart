import 'package:flutter/material.dart';

import '../services/admin_repository.dart';
import '../widgets/admin_widgets.dart';

class AdminLivePanel extends StatefulWidget {
  const AdminLivePanel({
    required this.repository,
    required this.section,
    required this.title,
    super.key,
  });
  final AdminDataSource repository;
  final String section, title;
  @override
  State<AdminLivePanel> createState() => _AdminLivePanelState();
}

class _AdminLivePanelState extends State<AdminLivePanel> {
  int _page = 0;
  String _search = '';
  late Future<Object> _result = _load();
  Future<Object> _load() => widget.section == 'overview'
      ? widget.repository.counts()
      : widget.repository.records(widget.section, _page);
  void _refresh() => setState(() {
    _result = _load();
  });

  String _title(Map<String, dynamic> row) => switch (widget.section) {
    'seekers' => '${row['full_name'] ?? 'Unnamed seeker'}',
    'companies' => '${row['company_name']}',
    'jobs' => '${row['title']}',
    _ => '${(row['jobs'] as Map?)?['title'] ?? 'Application'}',
  };
  String _details(Map<String, dynamic> row) => switch (widget.section) {
    'seekers' => '${row['account_status']}',
    'companies' =>
      '${row['city'] ?? ''} ${row['province'] ?? ''} · '
          '${row['is_active'] == true ? 'Active' : 'Inactive'}',
    'jobs' =>
      '${(row['employers'] as Map?)?['company_name'] ?? ''} · '
          '${row['status']} · ${row['work_arrangement']}',
    _ =>
      '${((row['job_seeker_profiles'] as Map?)?['profiles'] as Map?)?['full_name'] ?? 'Applicant'} · '
          '${row['status']} · ${row['submitted_at']}',
  };

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      AdminPageHeader(
        title: widget.title,
        subtitle: 'Live records from the shared EnableWork+ backend.',
      ),
      Align(
        alignment: Alignment.centerLeft,
        child: OutlinedButton.icon(
          onPressed: _refresh,
          icon: const Icon(Icons.refresh),
          label: const Text('Refresh'),
        ),
      ),
      const SizedBox(height: 16),
      FutureBuilder<Object>(
        future: _result,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(
              child: CircularProgressIndicator(
                semanticsLabel: 'Loading administrator records',
              ),
            );
          }
          if (snapshot.hasError) {
            return const AdminUnavailableCard(
              title: 'Records could not be loaded',
              message: 'Check your connection and administrator access, then select Refresh.',
            );
          }
          if (widget.section == 'overview') {
            final counts = snapshot.data! as Map<String, int>;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final item in counts.entries)
                  Card(
                    child: ListTile(
                      title: Text(item.key),
                      trailing: Text(
                        '${item.value}',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                    ),
                  ),
                const AdminUnavailableCard(
                  title: 'AI matching deferred',
                  message:
                      'AI scanning and recommendations are not yet available.',
                ),
              ],
            );
          }
          final rows = snapshot.data! as List<Map<String, dynamic>>;
          final filtered = rows
              .where(
                (r) => '${_title(r)} ${_details(r)}'.toLowerCase().contains(
                  _search.toLowerCase(),
                ),
              )
              .toList();
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (widget.section == 'companies')
                const Text(
                  'Companies are records only; they do not have accounts or dashboards.',
                ),
              TextField(
                decoration: const InputDecoration(
                  labelText: 'Search this page',
                  prefixIcon: Icon(Icons.search),
                ),
                onChanged: (value) => setState(() => _search = value),
              ),
              const SizedBox(height: 12),
              if (filtered.isEmpty)
                const AdminEmptyTable(
                  title: 'No matching records',
                  message: 'No records are available on this page. No sample data is shown.',
                ),
              for (final row in filtered) _recordCard(row),
              Wrap(
                spacing: 12,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  OutlinedButton(
                    onPressed: _page == 0
                        ? null
                        : () {
                            _page--;
                            _refresh();
                          },
                    child: const Text('Previous'),
                  ),
                  Text('Page ${_page + 1}'),
                  OutlinedButton(
                    onPressed: rows.length < 25
                        ? null
                        : () {
                            _page++;
                            _refresh();
                          },
                    child: const Text('Next'),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    ],
  );

  Widget _recordCard(Map<String, dynamic> row) {
    final applicationId = row['id'] as String?;
    final status = row['status'] as String?;
    final canUpdate =
        widget.section == 'applications' &&
        applicationId != null &&
        status != null &&
        widget.repository is AdminRepository;
    return Card(
      child: ListTile(
        title: Text(_title(row)),
        subtitle: Text(_details(row)),
        trailing: canUpdate
            ? _ApplicationStatusAction(
                status: status,
                onChanged: (next) async {
                  await (widget.repository as AdminRepository)
                      .updateApplicationStatus(applicationId, next);
                  if (mounted) _refresh();
                },
              )
            : null,
      ),
    );
  }
}

class _ApplicationStatusAction extends StatefulWidget {
  const _ApplicationStatusAction({
    required this.status,
    required this.onChanged,
  });
  final String status;
  final Future<void> Function(String status) onChanged;
  @override
  State<_ApplicationStatusAction> createState() =>
      _ApplicationStatusActionState();
}

class _ApplicationStatusActionState extends State<_ApplicationStatusAction> {
  bool _busy = false;
  late String _status = widget.status;

  List<String> get _options => switch (_status) {
    'submitted' => const ['under_review', 'rejected'],
    'under_review' => const ['shortlisted', 'rejected'],
    'shortlisted' => const ['hired', 'rejected'],
    _ => const [],
  };

  @override
  Widget build(BuildContext context) {
    final options = [_status, ..._options];
    return DropdownButton<String>(
      value: _status,
      items: [
        for (final value in options)
          DropdownMenuItem(value: value, child: Text(value)),
      ],
      onChanged: _busy
          ? null
          : (next) async {
              if (next == null || next == _status) return;
              setState(() => _busy = true);
              try {
                await widget.onChanged(next);
                if (mounted) setState(() => _status = next);
              } catch (_) {
                if (!mounted) return;
                ScaffoldMessenger.of(this.context).showSnackBar(
                  const SnackBar(content: Text('Status could not be updated.')),
                );
              } finally {
                if (mounted) setState(() => _busy = false);
              }
            },
    );
  }
}
