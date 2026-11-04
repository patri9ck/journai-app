// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Patrick Zwick

import 'package:flutter/material.dart';

import '../../messages/app_localizations.dart';
import '../../model/life_band_style.dart';
import '../shared/style_picker.dart';

class LifeBandStyleSheet extends StatefulWidget {
  final LifeBandStyle style;

  const LifeBandStyleSheet({super.key, required this.style});

  @override
  State<LifeBandStyleSheet> createState() => _LifeBandStyleSheetState();
}

class _LifeBandStyleSheetState extends State<LifeBandStyleSheet> {
  late LifeBandStyle _style = widget.style;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;

    return StyleSheetFrame(
      title: localizations.lifeBandCustomize,
      sections: [
        StyleSection(
          label: localizations.lifeBandShow,
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilterChip(
                label: Text(localizations.lifeBandShowStripes),
                selected: _style.showStripes,
                onSelected: _style.showStamps
                    ? (showStripes) => setState(() => _style = _style.copyWith(showStripes: showStripes))
                    : null,
              ),
              FilterChip(
                label: Text(localizations.lifeBandShowStamps),
                selected: _style.showStamps,
                onSelected: _style.showStripes
                    ? (showStamps) => setState(() => _style = _style.copyWith(showStamps: showStamps))
                    : null,
              ),
            ],
          ),
        ),
        ...posterStyleSections(localizations, _style.poster, localizations.memoriesLifeBand, (poster) => setState(() => _style = _style.copyWith(poster: poster))),
        if (_style.showStamps) ...[
          StyleSection(
            label: localizations.stampLayout,
            child: StyleChoices(
              values: StampLayout.values,
              selected: _style.stampLayout,
              label: (layout) => switch (layout) {
                StampLayout.tidy => localizations.stampLayoutTidy,
                StampLayout.scattered => localizations.stampLayoutScattered,
              },
              onSelected: (layout) => setState(() => _style = _style.copyWith(stampLayout: layout)),
            ),
          ),
          StyleSection(
            label: localizations.stampSize,
            child: StyleChoices(
              values: StampSize.values,
              selected: _style.stampSize,
              label: (size) => switch (size) {
                StampSize.small => localizations.stampSizeSmall,
                StampSize.medium => localizations.stampSizeMedium,
                StampSize.large => localizations.stampSizeLarge,
              },
              onSelected: (size) => setState(() => _style = _style.copyWith(stampSize: size)),
            ),
          ),
        ],
      ],
      onReset: () => setState(() => _style = const LifeBandStyle()),
      onSave: () => Navigator.of(context).pop(_style),
    );
  }
}
