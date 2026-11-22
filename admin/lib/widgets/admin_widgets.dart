import 'package:flutter/material.dart';

import '../theme/admin_theme.dart';

class AdminBrand extends StatelessWidget {
  const AdminBrand({this.compact = false, super.key});
  final bool compact;

  @override
  Widget build(BuildContext context) => Semantics(
    image: true,
    label: 'EnableWork+ administrator console',
    child: Image.asset(
      'assets/branding/enablework-plus-logo.png',
      height: compact ? 42 : 92,
      fit: BoxFit.contain,
      alignment: compact ? Alignment.centerLeft : Alignment.center,
    ),
  );
}

class AdminPageHeader extends StatelessWidget {
  const AdminPageHeader({
    required this.title,
    required this.subtitle,
    super.key,
  });
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.headlineMedium
              ?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        Text(
          subtitle,
          style: Theme.of(context).textTheme.bodyLarge
              ?.copyWith(color: AdminColors.muted),
        ),
      ],
    ),
  );
}

class AdminMetricCard extends StatelessWidget {
  const AdminMetricCard({
    required this.label,
    required this.icon,
    this.accent,
    super.key,
  });
  final String label;
  final IconData icon;
  final Color? accent;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(AdminSpacing.card),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: (accent ?? AdminColors.royalBlue).withValues(
              alpha: .1,
            ),
            foregroundColor: accent ?? AdminColors.royalBlue,
            child: Icon(icon),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(
                  'Awaiting live data',
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: AdminColors.muted),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class AdminUnavailableCard extends StatelessWidget {
  const AdminUnavailableCard({
    required this.title,
    required this.message,
    super.key,
  });
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(AdminSpacing.card),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, color: AdminColors.royalBlue),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 6),
                Text(message),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class AdminEmptyTable extends StatelessWidget {
  const AdminEmptyTable({
    required this.title,
    required this.message,
    super.key,
  });
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 42),
      child: Column(
        children: [
          Icon(Icons.table_rows_outlined, size: 40, color: AdminColors.muted),
          const SizedBox(height: 12),
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 6),
          Text(message, textAlign: TextAlign.center),
        ],
      ),
    ),
  );
}
