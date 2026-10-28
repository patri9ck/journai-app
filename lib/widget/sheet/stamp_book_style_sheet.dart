// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Patrick Zwick

import 'package:flutter/material.dart';

import '../../messages/app_localizations.dart';
import '../../model/stamp_book_style.dart';
import '../shared/style_picker.dart';

class StampBookStyleSheet extends StatefulWidget {
  final StampBookStyle style;

  const StampBookStyleSheet({super.key, required this.style});

  @override
  State<StampBookStyleSheet> createState() => _StampBookStyleSheetState();
}

class _StampBookStyleSheetState extends State<StampBookStyleSheet> {
  late StampBookStyle _style = widget.style;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;

    return StyleSheetFrame(
      title: localizations.stampBookCustomize,
      sections: [
        ...posterStyleSections(localizations, _style.poster, (poster) => setState(() => _style = _style.copyWith(poster: poster))),
        StyleSection(
          label: localizations.stampBookFrame,
          child: StyleChoices(
            values: StampBookFrame.values,
            selected: _style.frame,
            label: (frame) => switch (frame) {
              StampBookFrame.none => localizations.stampBookFrameNone,
              StampBookFrame.line => localizations.stampBookFrameLine,
              StampBookFrame.double => localizations.stampBookFrameDouble,
            },
            onSelected: (frame) => setState(() => _style = _style.copyWith(frame: frame)),
          ),
        ),
        StyleSection(
          label: localizations.stampBookLayout,
          child: StyleChoices(
            values: StampBookLayout.values,
            selected: _style.layout,
            label: (layout) => switch (layout) {
              StampBookLayout.tidy => localizations.stampBookLayoutTidy,
              StampBookLayout.scattered => localizations.stampBookLayoutScattered,
            },
            onSelected: (layout) => setState(() => _style = _style.copyWith(layout: layout)),
          ),
        ),
        StyleSection(
          label: localizations.stampBookSize,
          child: StyleChoices(
            values: StampBookSize.values,
            selected: _style.size,
            label: (size) => switch (size) {
              StampBookSize.small => localizations.stampBookSizeSmall,
              StampBookSize.medium => localizations.stampBookSizeMedium,
              StampBookSize.large => localizations.stampBookSizeLarge,
            },
            onSelected: (size) => setState(() => _style = _style.copyWith(size: size)),
          ),
        ),
      ],
      onReset: () => setState(() => _style = const StampBookStyle()),
      onSave: () => Navigator.of(context).pop(_style),
    );
  }
}
