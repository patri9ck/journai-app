// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Patrick Zwick

import 'package:flutter/material.dart';

import '../../messages/app_localizations.dart';
import '../../model/data.dart';
import '../../model/stamp_style.dart';
import '../../model/trip.dart';
import '../../service/services.dart';
import '../shared/document_shared.dart';
import '../shared/style_picker.dart';
import '../shared/travel_stamp.dart';

class StampStyleSheet extends StatefulWidget {
  final Trip trip;
  final double? temperature;

  const StampStyleSheet({super.key, required this.trip, required this.temperature});

  @override
  State<StampStyleSheet> createState() => _StampStyleSheetState();
}

class _StampStyleSheetState extends State<StampStyleSheet> {
  late StampStyle _style = widget.trip.stampStyle;
  bool _saving = false;

  Trip get _preview => widget.trip.copyWith(stampStyle: _style);

  Future<void> _save() async {
    setState(() => _saving = true);

    final trip = _preview;

    final saved = await ensureAndSave(
      context,
      () => dataService.updateData(trip.id!, Data(feature: 'TRIP', fields: trip.toFields())),
    );

    if (saved) {
      await dataService.getData();
    }

    if (!mounted) {
      return;
    }

    setState(() => _saving = false);

    if (saved) {
      Navigator.of(context).pop(trip);
    }
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;

    return StyleSheetFrame(
      title: localizations.stampCustomize,
      preview: TravelStamp(trip: _preview, temperature: widget.temperature, size: 140),
      sections: [
        StyleSection(
          label: localizations.stampShape,
          child: StyleChoices(
            values: StampShape.values,
            selected: _style.shape,
            label: (shape) => switch (shape) {
              StampShape.circle => localizations.stampShapeCircle,
              StampShape.rectangle => localizations.stampShapeRectangle,
              StampShape.oval => localizations.stampShapeOval,
              StampShape.hexagon => localizations.stampShapeHexagon,
            },
            onSelected: (shape) => setState(() => _style = StampStyle(shape: shape, font: _style.font, color: _style.color)),
          ),
        ),
        FontChoices(
          label: localizations.stampFont,
          selected: _style.font,
          onSelected: (font) => setState(() => _style = StampStyle(shape: _style.shape, font: font, color: _style.color)),
        ),
        StyleSection(
          label: localizations.stampColor,
          child: ColorChoices(
            colors: stampColors,
            selected: _style.color,
            onSelected: (color) => setState(() => _style = StampStyle(shape: _style.shape, font: _style.font, color: color)),
          ),
        ),
      ],
      onReset: () => setState(() => _style = const StampStyle()),
      onSave: _saving ? null : _save,
    );
  }
}
