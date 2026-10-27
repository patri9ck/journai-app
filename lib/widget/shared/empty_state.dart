// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Patrick Zwick

import 'package:flutter/material.dart';

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String? title;
  final String? text;
  final List<Widget> actions;

  const EmptyState({required this.icon, this.title, this.text, this.actions = const [], super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mutedColor = theme.colorScheme.onSurface.withValues(alpha: 0.6);

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(32, 32, 32, 96),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: theme.colorScheme.onSurface.withValues(alpha: 0.3)),
            if (title != null) ...[
              const SizedBox(height: 16),
              Text(title!, textAlign: TextAlign.center, style: theme.textTheme.titleMedium),
            ],
            if (text != null) ...[
              SizedBox(height: title == null ? 16 : 8),
              Text(
                text!,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(color: mutedColor),
              ),
            ],
            if (actions.isNotEmpty) ...[
              const SizedBox(height: 24),
              for (final (index, action) in actions.indexed) ...[if (index > 0) const SizedBox(height: 8), action],
            ],
          ],
        ),
      ),
    );
  }
}
