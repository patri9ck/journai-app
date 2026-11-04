// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Patrick Zwick

import 'package:flutter/material.dart';

import '../../messages/app_localizations.dart';
import 'loading_button.dart';

class FormSheet extends StatelessWidget {
  final String title;
  final String? subtitle;
  final List<Widget> children;
  final VoidCallback? onSave;
  final bool saving;

  const FormSheet({
    required this.title,
    this.subtitle,
    required this.children,
    this.onSave,
    this.saving = false,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(left: 24, right: 24, top: 24, bottom: MediaQuery.of(context).viewInsets.bottom + 24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(title, style: theme.textTheme.titleLarge),
              if (subtitle != null) ...[const SizedBox(height: 8), Text(subtitle!, style: theme.textTheme.bodySmall)],
              const SizedBox(height: 16),
              ...children,
              if (onSave != null) ...[
                const SizedBox(height: 20),
                LoadingButton(loading: saving, onPressed: onSave, label: AppLocalizations.of(context)!.documentSave),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
