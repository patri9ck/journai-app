// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Patrick Zwick

import 'package:flutter/material.dart';

import '../../messages/app_localizations.dart';
import '../../model/poster_style.dart';
import '../shared/style_picker.dart';

class PosterStyleSheet extends StatefulWidget {
  final String title;
  final String defaultHeading;
  final PosterStyle style;

  const PosterStyleSheet({super.key, required this.title, required this.defaultHeading, required this.style});

  @override
  State<PosterStyleSheet> createState() => _PosterStyleSheetState();
}

class _PosterStyleSheetState extends State<PosterStyleSheet> {
  late PosterStyle _style = widget.style;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;

    return StyleSheetFrame(
      title: widget.title,
      sections: posterStyleSections(localizations, _style, widget.defaultHeading, (style) => setState(() => _style = style)),
      onReset: () => setState(() => _style = const PosterStyle()),
      onSave: () => Navigator.of(context).pop(_style),
    );
  }
}
