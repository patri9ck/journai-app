// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Patrick Zwick

import 'package:flutter/material.dart';

import '../../messages/app_localizations.dart';
import '../../model/stamp_book_style.dart';

class StampBookStyleSheet extends StatefulWidget {
  final StampBookStyle style;

  const StampBookStyleSheet({super.key, required this.style});

  @override
  State<StampBookStyleSheet> createState() => _StampBookStyleSheetState();
}

class _StampBookStyleSheetState extends State<StampBookStyleSheet> {
  late Color _background = widget.style.background;
  late StampBookFrame _frame = widget.style.frame;
  late StampBookLayout _layout = widget.style.layout;
  late StampBookSize _size = widget.style.size;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(localizations.stampBookCustomize, style: theme.textTheme.titleMedium),
            const SizedBox(height: 16),
            Text(localizations.stampBookBackground, style: theme.textTheme.labelLarge),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final background in stampBookBackgrounds)
                  GestureDetector(
                    onTap: () => setState(() => _background = background),
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: background,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: _background == background ? theme.colorScheme.primary : theme.colorScheme.outlineVariant,
                          width: _background == background ? 3 : 1,
                          strokeAlign: BorderSide.strokeAlignOutside,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Text(localizations.stampBookFrame, style: theme.textTheme.labelLarge),
            const SizedBox(height: 8),
            _choices(
              StampBookFrame.values,
              _frame,
              (frame) => switch (frame) {
                StampBookFrame.none => localizations.stampBookFrameNone,
                StampBookFrame.line => localizations.stampBookFrameLine,
                StampBookFrame.double => localizations.stampBookFrameDouble,
              },
              (frame) => setState(() => _frame = frame),
            ),
            const SizedBox(height: 16),
            Text(localizations.stampBookLayout, style: theme.textTheme.labelLarge),
            const SizedBox(height: 8),
            _choices(
              StampBookLayout.values,
              _layout,
              (layout) => switch (layout) {
                StampBookLayout.tidy => localizations.stampBookLayoutTidy,
                StampBookLayout.scattered => localizations.stampBookLayoutScattered,
              },
              (layout) => setState(() => _layout = layout),
            ),
            const SizedBox(height: 16),
            Text(localizations.stampBookSize, style: theme.textTheme.labelLarge),
            const SizedBox(height: 8),
            _choices(
              StampBookSize.values,
              _size,
              (size) => switch (size) {
                StampBookSize.small => localizations.stampBookSizeSmall,
                StampBookSize.medium => localizations.stampBookSizeMedium,
                StampBookSize.large => localizations.stampBookSizeLarge,
              },
              (size) => setState(() => _size = size),
            ),
            const SizedBox(height: 24),
            OutlinedButton(
              onPressed: () => setState(() {
                const style = StampBookStyle();

                _background = style.background;
                _frame = style.frame;
                _layout = style.layout;
                _size = style.size;
              }),
              child: Text(localizations.stampReset),
            ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(
                StampBookStyle(background: _background, frame: _frame, layout: _layout, size: _size),
              ),
              child: Text(localizations.documentSave),
            ),
          ],
        ),
      ),
    );
  }

  Widget _choices<T>(List<T> values, T selected, String Function(T) label, ValueChanged<T> onSelected) => Wrap(
    spacing: 8,
    runSpacing: 8,
    children: [
      for (final value in values)
        ChoiceChip(
          label: Text(label(value)),
          selected: value == selected,
          onSelected: (_) => onSelected(value),
        ),
    ],
  );
}
