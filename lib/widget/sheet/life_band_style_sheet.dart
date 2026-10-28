// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Patrick Zwick

import 'package:flutter/material.dart';

import '../../messages/app_localizations.dart';
import '../../model/poster_style.dart';
import '../shared/style_picker.dart';

class LifeBandStyleSheet extends StatefulWidget {
  final PosterStyle style;

  const LifeBandStyleSheet({super.key, required this.style});

  @override
  State<LifeBandStyleSheet> createState() => _LifeBandStyleSheetState();
}

class _LifeBandStyleSheetState extends State<LifeBandStyleSheet> {
  late PosterStyle _style = widget.style;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;

    return StyleSheetFrame(
      title: localizations.lifeBandCustomize,
      sections: posterStyleSections(localizations, _style, (style) => setState(() => _style = style)),
      onReset: () => setState(() => _style = const PosterStyle()),
      onSave: () => Navigator.of(context).pop(_style),
    );
  }
}
