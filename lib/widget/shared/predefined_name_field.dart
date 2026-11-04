// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Patrick Zwick

import 'package:flutter/material.dart';

import '../../messages/app_localizations.dart';

class PredefinedNameField extends StatefulWidget {
  final TextEditingController controller;
  final List<String> names;
  final String selectLabel;
  final String nameLabel;
  final String? errorText;

  const PredefinedNameField({
    required this.controller,
    required this.names,
    required this.selectLabel,
    required this.nameLabel,
    this.errorText,
    super.key,
  });

  @override
  State<PredefinedNameField> createState() => _PredefinedNameFieldState();
}

class _PredefinedNameFieldState extends State<PredefinedNameField> {
  late bool _showCustomInput = widget.controller.text.isNotEmpty && !widget.names.contains(widget.controller.text);

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          widget.selectLabel,
          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final name in widget.names)
              ChoiceChip(
                label: Text(name),
                selected: widget.controller.text == name,
                onSelected: (_) => setState(() {
                  widget.controller.text = name;
                  _showCustomInput = false;
                }),
              ),
            ChoiceChip(
              label: Text(localizations.customName),
              selected: _showCustomInput,
              onSelected: (_) => setState(() {
                _showCustomInput = true;
                widget.controller.clear();
              }),
            ),
          ],
        ),
        if (_showCustomInput || widget.errorText != null) ...[
          const SizedBox(height: 12),
          TextField(
            controller: widget.controller,
            decoration: InputDecoration(labelText: '${widget.nameLabel} *', errorText: widget.errorText),
            textCapitalization: TextCapitalization.sentences,
            autofocus: _showCustomInput,
          ),
        ],
      ],
    );
  }
}
