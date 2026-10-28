// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Patrick Zwick

import 'package:flutter/material.dart';

import '../../messages/app_localizations.dart';
import '../../model/data.dart';
import '../../model/stamp_style.dart';
import '../../model/trip.dart';
import '../../service/services.dart';
import '../shared/document_shared.dart';
import '../shared/travel_stamp.dart';

class StampStyleSheet extends StatefulWidget {
  final Trip trip;
  final double? temperature;

  const StampStyleSheet({super.key, required this.trip, required this.temperature});

  @override
  State<StampStyleSheet> createState() => _StampStyleSheetState();
}

class _StampStyleSheetState extends State<StampStyleSheet> {
  late StampShape? _shape = widget.trip.stampStyle.shape;
  late StampFont _font = widget.trip.stampStyle.font;
  late Color? _color = widget.trip.stampStyle.color;
  bool _saving = false;

  Trip get _preview => Trip(
    id: widget.trip.id,
    countryCode: widget.trip.countryCode,
    countryName: widget.trip.countryName,
    start: widget.trip.start,
    end: widget.trip.end,
    stampStyle: StampStyle(shape: _shape, font: _font, color: _color),
  );

  Future<void> _save() async {
    setState(() => _saving = true);

    final trip = _preview;

    final saved = await ensureAndSave(
      context,
      () => dataService.updateData(trip.id!, Data(feature: 'TRIP', fields: trip.toFields())),
    );

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
    final theme = Theme.of(context);

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(localizations.stampCustomize, style: theme.textTheme.titleMedium),
            const SizedBox(height: 16),
            Center(child: TravelStamp(trip: _preview, temperature: widget.temperature, size: 140)),
            const SizedBox(height: 16),
            Text(localizations.stampShape, style: theme.textTheme.labelLarge),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ChoiceChip(
                  label: Text(localizations.stampAutomatic),
                  selected: _shape == null,
                  onSelected: (_) => setState(() => _shape = null),
                ),
                for (final shape in StampShape.values)
                  ChoiceChip(
                    label: Text(_shapeLabel(localizations, shape)),
                    selected: _shape == shape,
                    onSelected: (_) => setState(() => _shape = shape),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Text(localizations.stampFont, style: theme.textTheme.labelLarge),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final font in StampFont.values)
                  ChoiceChip(
                    label: Text(_fontLabel(localizations, font)),
                    selected: _font == font,
                    onSelected: (_) => setState(() => _font = font),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Text(localizations.stampColor, style: theme.textTheme.labelLarge),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ChoiceChip(
                  label: Text(localizations.stampAutomatic),
                  selected: _color == null,
                  onSelected: (_) => setState(() => _color = null),
                ),
                for (final color in stampColors)
                  _ColorSwatch(
                    color: color,
                    selected: _color == color,
                    onTap: () => setState(() => _color = color),
                  ),
              ],
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: Text(localizations.documentSave),
            ),
          ],
        ),
      ),
    );
  }

  String _shapeLabel(AppLocalizations localizations, StampShape shape) => switch (shape) {
    StampShape.circle => localizations.stampShapeCircle,
    StampShape.rectangle => localizations.stampShapeRectangle,
    StampShape.oval => localizations.stampShapeOval,
    StampShape.hexagon => localizations.stampShapeHexagon,
  };

  String _fontLabel(AppLocalizations localizations, StampFont font) => switch (font) {
    StampFont.sans => localizations.stampFontSans,
    StampFont.serif => localizations.stampFontSerif,
    StampFont.typewriter => localizations.stampFontTypewriter,
  };
}

class _ColorSwatch extends StatelessWidget {
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const _ColorSwatch({required this.color, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: selected ? Theme.of(context).colorScheme.primary : Colors.transparent,
            width: 3,
            strokeAlign: BorderSide.strokeAlignOutside,
          ),
        ),
        child: selected ? const Icon(Icons.check, size: 18, color: Colors.white) : null,
      ),
    );
  }
}
