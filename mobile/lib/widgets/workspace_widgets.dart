import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class BusyIndicator extends StatelessWidget {
  const BusyIndicator({required this.label, super.key});
  final String label;
  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!MediaQuery.disableAnimationsOf(context))
            const CircularProgressIndicator(),
          const SizedBox(height: 12),
          Text(label, textAlign: TextAlign.center),
        ],
      ),
    ),
  );
}

class SectionCard extends StatelessWidget {
  const SectionCard({
    required this.title,
    required this.children,
    this.borderless = false,
    super.key,
  });
  final String title;
  final List<Widget> children;
  final bool borderless;
  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 16),
    shape: borderless
        ? RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.card),
            side: BorderSide.none,
          )
        : null,
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.card),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: Text(title, style: Theme.of(context).textTheme.titleLarge),
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    ),
  );
}

class WorkspaceError extends StatelessWidget {
  const WorkspaceError({
    required this.message,
    required this.onDismiss,
    super.key,
  });
  final String message;
  final VoidCallback onDismiss;
  @override
  Widget build(BuildContext context) => Material(
    color: Theme.of(context).colorScheme.errorContainer,
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            liveRegion: true,
            child: Text(
              message,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onErrorContainer,
              ),
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: onDismiss,
              child: const Text('Dismiss'),
            ),
          ),
        ],
      ),
    ),
  );
}

class CareerHeading extends StatelessWidget {
  const CareerHeading(this.title, {super.key});
  final String title;
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 18),
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.primaryContainer,
      borderRadius: BorderRadius.circular(22),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          header: true,
          child: Text(
            title,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              color: Theme.of(context).colorScheme.onPrimaryContainer,
            ),
          ),
        ),
      ],
    ),
  );
}

/// A compact, reusable status block for screens that are waiting on a live
/// backend resource. It keeps the authenticated app honest: unavailable data
/// is never replaced with invented jobs, scores, or recommendations.
class UnavailablePanel extends StatelessWidget {
  const UnavailablePanel({
    required this.title,
    required this.message,
    this.action,
    super.key,
  });
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      color: colors.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.card),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.cloud_off_outlined, color: colors.primary, size: 28),
            const SizedBox(height: 12),
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(message),
            if (action != null) ...[const SizedBox(height: 10), action!],
          ],
        ),
      ),
    );
  }
}
