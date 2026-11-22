import 'package:flutter/material.dart';

import '../theme/admin_theme.dart';
import '../widgets/admin_widgets.dart';
import '../services/admin_repository.dart';
import 'admin_live_panel.dart';

enum AdminSection { overview, seekers, companies, jobs, applications, activity }

class AdminShell extends StatefulWidget {
  const AdminShell({required this.onSignOut, this.repository, super.key});
  final Future<void> Function() onSignOut;
  final AdminRepository? repository;

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  AdminSection _section = AdminSection.overview;

  String get _title => switch (_section) {
    AdminSection.overview => 'Platform overview',
    AdminSection.seekers => 'PWD job seekers',
    AdminSection.companies => 'Companies',
    AdminSection.jobs => 'Job postings',
    AdminSection.applications => 'Applications',
    AdminSection.activity => 'System activity',
  };

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final compact = constraints.maxWidth < 900;
      return Scaffold(
        appBar: compact
            ? AppBar(
                title: Text(_title),
                actions: [
                  IconButton(
                    tooltip: 'Sign out',
                    onPressed: widget.onSignOut,
                    icon: const Icon(Icons.logout),
                  ),
                ],
              )
            : null,
        drawer: compact ? Drawer(child: _navigation(compact: true)) : null,
        body: Row(
          children: [
            if (!compact) SizedBox(width: 252, child: _navigation()),
            Expanded(
              child: ColoredBox(
                color: AdminColors.canvas,
                child: SafeArea(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.all(compact ? 18 : AdminSpacing.page),
                    child: _content(),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    },
  );

  Widget _navigation({bool compact = false}) => Material(
    color: Colors.white,
    child: SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
            child: AdminBrand(compact: compact),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
            child: Text(
              'SYSTEM ADMINISTRATOR',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: AdminColors.muted,
                letterSpacing: 1.1,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                _navItem(
                  AdminSection.overview,
                  Icons.dashboard_outlined,
                  'Overview',
                ),
                _navItem(
                  AdminSection.seekers,
                  Icons.people_outline,
                  'PWD Job Seekers',
                ),
                _navItem(
                  AdminSection.companies,
                  Icons.business_outlined,
                  'Companies',
                ),
                _navItem(AdminSection.jobs, Icons.work_outline, 'Job Postings'),
                _navItem(
                  AdminSection.applications,
                  Icons.assignment_outlined,
                  'Applications',
                ),
                _navItem(
                  AdminSection.activity,
                  Icons.history_outlined,
                  'System Activity',
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(14),
            child: OutlinedButton.icon(
              onPressed: widget.onSignOut,
              icon: const Icon(Icons.logout),
              label: const Text('Sign out'),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _navItem(AdminSection section, IconData icon, String label) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: ListTile(
      selected: _section == section,
      selectedTileColor: AdminColors.royalBlue.withValues(alpha: .08),
      selectedColor: AdminColors.royalBlue,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      leading: Icon(icon),
      title: Text(label),
      onTap: () {
        setState(() => _section = section);
        if (Navigator.of(context).canPop()) Navigator.of(context).pop();
      },
    ),
  );

  Widget _content() {
    if (widget.repository != null && _section != AdminSection.activity) {
      return AdminLivePanel(
        key: ValueKey(_section),
        repository: widget.repository!,
        section: _section.name,
        title: _title,
      );
    }
    return switch (_section) {
      AdminSection.overview => const _OverviewPage(),
      AdminSection.seekers => const _SeekersPage(),
      AdminSection.companies => const _CompaniesPage(),
      AdminSection.jobs => const _JobsPage(),
      AdminSection.applications => const _ApplicationsPage(),
      AdminSection.activity => const _ActivityPage(),
    };
  }
}

class _OverviewPage extends StatelessWidget {
  const _OverviewPage();

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const AdminPageHeader(
        title: 'Platform overview',
        subtitle: 'Monitor EnableWork+ operations from one secure workspace.',
      ),
      const AdminUnavailableCard(
        title: 'Live metrics are not connected',
        message: 'Connect the approved local Supabase instance after the localhost-only Docker gate is verified. No preview records are shown here.',
      ),
      const SizedBox(height: 18),
      LayoutBuilder(
        builder: (context, box) {
          final columns = box.maxWidth >= 920
              ? 4
              : box.maxWidth >= 520
              ? 2
              : 1;
          final width = columns == 1
              ? box.maxWidth
              : (box.maxWidth - (columns - 1) * 14) / columns;
          return Wrap(
            spacing: 14,
            runSpacing: 14,
            children: [
              SizedBox(
                width: width,
                child: const AdminMetricCard(
                  label: 'Registered PWD job seekers',
                  icon: Icons.people_outline,
                ),
              ),
              SizedBox(
                width: width,
                child: const AdminMetricCard(
                  label: 'Active companies',
                  icon: Icons.business_outlined,
                  accent: AdminColors.success,
                ),
              ),
              SizedBox(
                width: width,
                child: const AdminMetricCard(
                  label: 'Published job postings',
                  icon: Icons.work_outline,
                  accent: AdminColors.royalBlue,
                ),
              ),
              SizedBox(
                width: width,
                child: const AdminMetricCard(
                  label: 'Submitted applications',
                  icon: Icons.assignment_outlined,
                  accent: AdminColors.crimson,
                ),
              ),
            ],
          );
        },
      ),
      const SizedBox(height: 24),
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Expanded(
            child: AdminEmptyTable(
              title: 'Recent activity unavailable',
              message: 'The current migrations do not expose an administrator-readable activity feed. This module remains intentionally empty until a reviewed audit design is approved.',
            ),
          ),
          const SizedBox(width: 16),
          if (MediaQuery.sizeOf(context).width >= 760)
            const SizedBox(
              width: 300,
              child: AdminUnavailableCard(
                title: 'AI matching deferred',
                message: 'No AI scores or recommendations are presented until the approved integration exists.',
              ),
            ),
        ],
      ),
    ],
  );
}

class _SeekersPage extends StatelessWidget {
  const _SeekersPage();
  @override
  Widget build(BuildContext context) => const _ManagementPage(
    title: 'PWD job seekers',
    subtitle:
        'Review registered seeker profiles and accessibility preferences.',
    searchHint: 'Search by name or account status',
    emptyTitle: 'No seeker records loaded',
    emptyMessage: 'Live seeker data will appear after the administrator Supabase integration is enabled. Private resume files are never exposed as public URLs.',
    icon: Icons.people_outline,
  );
}

class _CompaniesPage extends StatelessWidget {
  const _CompaniesPage();
  @override
  Widget build(BuildContext context) => const _ManagementPage(
    title: 'Companies',
    subtitle: 'Manage employer records used by published job postings. Companies do not have accounts or dashboards.',
    searchHint: 'Search company name or location',
    emptyTitle: 'No company records loaded',
    emptyMessage: 'Company records are managed by the System Administrator. Live data and write actions remain disabled until backend authorization is connected.',
    icon: Icons.business_outlined,
    actionLabel: 'Add company',
  );
}

class _JobsPage extends StatelessWidget {
  const _JobsPage();
  @override
  Widget build(BuildContext context) => const _ManagementPage(
    title: 'Job postings',
    subtitle: 'Create, review, publish, and close jobs associated with active companies.',
    searchHint: 'Search title, company, or status',
    emptyTitle: 'No job postings loaded',
    emptyMessage: 'Only jobs linked to active companies with valid publication rules should appear in mobile discovery.',
    icon: Icons.work_outline,
    actionLabel: 'Create job posting',
  );
}

class _ApplicationsPage extends StatelessWidget {
  const _ApplicationsPage();
  @override
  Widget build(BuildContext context) => const _ManagementPage(
    title: 'Applications',
    subtitle:
        'Monitor submitted applications and authorized status transitions.',
    searchHint: 'Search applicant, job, or status',
    emptyTitle: 'No applications loaded',
    emptyMessage: 'Application records are private and will be loaded through administrator-authorized RLS/RPC operations.',
    icon: Icons.assignment_outlined,
  );
}

class _ActivityPage extends StatelessWidget {
  const _ActivityPage();
  @override
  Widget build(BuildContext context) => const _ManagementPage(
    title: 'System activity',
    subtitle: 'Review important administrative operations when a supported audit feed is available.',
    searchHint: 'Search activity',
    emptyTitle: 'Activity feed not available',
    emptyMessage: 'The existing schema contains update audit triggers but no administrator-readable activity table. No history is fabricated.',
    icon: Icons.history_outlined,
  );
}

class _ManagementPage extends StatelessWidget {
  const _ManagementPage({
    required this.title,
    required this.subtitle,
    required this.searchHint,
    required this.emptyTitle,
    required this.emptyMessage,
    required this.icon,
    this.actionLabel,
  });
  final String title, subtitle, searchHint, emptyTitle, emptyMessage;
  final IconData icon;
  final String? actionLabel;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      AdminPageHeader(title: title, subtitle: subtitle),
      LayoutBuilder(
        builder: (context, constraints) {
          final search = TextField(
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              hintText: searchHint,
            ),
          );
          final action = actionLabel == null
              ? null
              : FilledButton.icon(
                  onPressed: null,
                  icon: const Icon(Icons.add),
                  label: Text(actionLabel!),
                );
          if (action == null || constraints.maxWidth >= 640) {
            return Row(
              children: [
                Expanded(child: search),
                if (action != null) ...[const SizedBox(width: 12), action],
              ],
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [search, const SizedBox(height: 12), action],
          );
        },
      ),
      const SizedBox(height: 18),
      Row(
        children: [
          OutlinedButton.icon(
            onPressed: null,
            icon: const Icon(Icons.filter_list),
            label: const Text('Filters'),
          ),
          const SizedBox(width: 10),
          Chip(
            avatar: Icon(icon, size: 16),
            label: const Text('Live data unavailable'),
          ),
        ],
      ),
      const SizedBox(height: 18),
      AdminEmptyTable(title: emptyTitle, message: emptyMessage),
    ],
  );
}
