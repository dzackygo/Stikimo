import 'package:flutter/material.dart';

class EmptyState extends StatelessWidget {
  const EmptyState({
    required this.icon,
    required this.title,
    required this.description,
    this.action,
    super.key,
  });

  final IconData icon;
  final String title;
  final String description;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const SizedBox(height: 32),
      Icon(icon, size: 56, color: Theme.of(context).colorScheme.primary),
      const SizedBox(height: 24),
      Text(title, style: Theme.of(context).textTheme.headlineMedium),
      const SizedBox(height: 12),
      Text(description, style: Theme.of(context).textTheme.bodyLarge),
      if (action != null) ...[const SizedBox(height: 24), action!],
    ],
  );
}
