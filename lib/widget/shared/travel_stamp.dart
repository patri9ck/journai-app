// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Patrick Zwick

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../../messages/app_localizations.dart';
import '../../model/stamp_style.dart';
import '../../model/trip.dart';
import '../../util/country_name.dart';
import '../../util/temperature_color.dart';
import 'stamp_font.dart';

class TravelStamp extends StatelessWidget {
  final Trip trip;
  final double? temperature;
  final double size;

  const TravelStamp({super.key, required this.trip, required this.temperature, this.size = 96});

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final dateLabel = DateFormat.yMMM(localizations.localeName).format(trip.start);
    final daysLabel = localizations.tripDays(trip.days.length);
    final countryName = tripCountryName(context, trip);
    final seed = trip.countryCode.codeUnits.fold(0, (sum, unit) => sum * 31 + unit);

    return Semantics(
      label: '$countryName, $dateLabel, $daysLabel',
      child: RepaintBoundary(
        child: CustomPaint(
          size: Size.square(size),
          painter: _StampPainter(
            seed: seed,
            shape: trip.stampStyle.shape ?? StampShape.values[seed.abs() % 3],
            font: trip.stampStyle.font,
            countryName: countryName.toUpperCase(),
            dateLabel: dateLabel.toUpperCase(),
            daysLabel: daysLabel.toUpperCase(),
            color: trip.stampStyle.color ?? stampInkColor(temperature),
          ),
        ),
      ),
    );
  }
}

class _StampPainter extends CustomPainter {
  final int seed;
  final StampShape shape;
  final StampFont font;
  final String countryName;
  final String dateLabel;
  final String daysLabel;
  final Color color;

  _StampPainter({
    required this.seed,
    required this.shape,
    required this.font,
    required this.countryName,
    required this.dateLabel,
    required this.daysLabel,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final random = Random(seed);
    final center = size.center(Offset.zero);
    final unit = size.width / 100;

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate((random.nextDouble() - 0.5) * 0.3);
    canvas.translate(-center.dx, -center.dy);

    final outline = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3 * unit;
    final innerOutline = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2 * unit;

    switch (shape) {
      case StampShape.circle:
        _paintBrokenCircle(canvas, center, 46 * unit, outline, random);
        canvas.drawCircle(center, 31 * unit, innerOutline);
        _paintArcText(canvas, center, 36.5 * unit, countryName, _style(7 * unit, letterSpacing: 1.2 * unit));
        _paintCenteredText(canvas, center.translate(0, -2 * unit), dateLabel, _style(11 * unit), maximumWidth: 56 * unit);
        _paintCenteredText(canvas, center.translate(0, 13 * unit), daysLabel, _style(6.5 * unit, letterSpacing: unit));
      case StampShape.rectangle:
        final outer = Rect.fromCenter(center: center, width: 92 * unit, height: 66 * unit);
        canvas.drawRRect(RRect.fromRectAndRadius(outer, Radius.circular(6 * unit)), outline);
        canvas.drawRRect(RRect.fromRectAndRadius(outer.deflate(5 * unit), Radius.circular(3 * unit)), innerOutline);
        _paintCenteredText(canvas, center.translate(0, -16 * unit), countryName, _style(8 * unit, letterSpacing: 1.2 * unit), maximumWidth: 76 * unit);
        _paintCenteredText(canvas, center.translate(0, 0), dateLabel, _style(12 * unit));
        _paintCenteredText(canvas, center.translate(0, 15 * unit), daysLabel, _style(6.5 * unit, letterSpacing: unit));
      case StampShape.oval:
        final outer = Rect.fromCenter(center: center, width: 94 * unit, height: 74 * unit);
        canvas.drawOval(outer, outline);
        canvas.drawOval(outer.deflate(6 * unit), innerOutline);
        _paintCenteredText(canvas, center.translate(0, -15 * unit), countryName, _style(8 * unit, letterSpacing: 1.2 * unit), maximumWidth: 66 * unit);
        _paintCenteredText(canvas, center.translate(0, 0), dateLabel, _style(12 * unit));
        _paintCenteredText(canvas, center.translate(0, 14 * unit), daysLabel, _style(6.5 * unit, letterSpacing: unit));
      case StampShape.hexagon:
        canvas.drawPath(_hexagon(center, 47 * unit), outline);
        canvas.drawPath(_hexagon(center, 40 * unit), innerOutline);
        _paintCenteredText(canvas, center.translate(0, -15 * unit), countryName, _style(8 * unit, letterSpacing: 1.2 * unit), maximumWidth: 60 * unit);
        _paintCenteredText(canvas, center.translate(0, 0), dateLabel, _style(12 * unit));
        _paintCenteredText(canvas, center.translate(0, 14 * unit), daysLabel, _style(6.5 * unit, letterSpacing: unit));
    }

    canvas.restore();
  }

  TextStyle _style(double fontSize, {double letterSpacing = 0}) {
    final style = TextStyle(
      color: color,
      fontSize: fontSize,
      fontWeight: font == StampFont.serif ? FontWeight.w400 : FontWeight.w700,
      letterSpacing: letterSpacing,
      height: 1,
    );

    return stampFontStyle(font, font == StampFont.serif ? style.copyWith(fontSize: fontSize * 1.1) : style);
  }

  Path _hexagon(Offset center, double radius) => Path()
    ..addPolygon([
      for (var corner = 0; corner < 6; corner++)
        center + Offset(radius * cos(corner * pi / 3), radius * sin(corner * pi / 3)),
    ], true);

  void _paintBrokenCircle(Canvas canvas, Offset center, double radius, Paint paint, Random random) {
    final rect = Rect.fromCircle(center: center, radius: radius);
    var angle = 0.0;

    while (angle < 2 * pi) {
      final sweep = 0.5 + random.nextDouble() * 0.9;

      canvas.drawArc(rect, angle, min(sweep, 2 * pi - angle), false, paint);
      angle += sweep + 0.03 + random.nextDouble() * 0.05;
    }
  }

  void _paintCenteredText(Canvas canvas, Offset center, String text, TextStyle style, {double? maximumWidth}) {
    final painter = TextPainter(text: TextSpan(text: text, style: style), textDirection: TextDirection.ltr, maxLines: 1)
      ..layout();

    if (maximumWidth != null && painter.width > maximumWidth) {
      painter
        ..text = TextSpan(text: text, style: style.copyWith(fontSize: style.fontSize! * maximumWidth / painter.width))
        ..layout();
    }

    painter.paint(canvas, center - Offset(painter.width / 2, painter.height / 2));
  }

  void _paintArcText(Canvas canvas, Offset center, double radius, String text, TextStyle style) {
    var painters = _characterPainters(text, style);
    var totalAngle = painters.fold(0.0, (sum, painter) => sum + painter.width / radius);

    if (totalAngle > 4.2) {
      painters = _characterPainters(text, style.copyWith(fontSize: style.fontSize! * 4.2 / totalAngle));
      totalAngle = painters.fold(0.0, (sum, painter) => sum + painter.width / radius);
    }

    var angle = -pi / 2 - totalAngle / 2;

    for (final painter in painters) {
      final halfAngle = painter.width / 2 / radius;

      angle += halfAngle;

      canvas.save();
      canvas.translate(center.dx + radius * cos(angle), center.dy + radius * sin(angle));
      canvas.rotate(angle + pi / 2);
      painter.paint(canvas, Offset(-painter.width / 2, -painter.height / 2));
      canvas.restore();

      angle += halfAngle;
    }
  }

  List<TextPainter> _characterPainters(String text, TextStyle style) => text.characters
      .map((character) => TextPainter(text: TextSpan(text: character, style: style), textDirection: TextDirection.ltr)..layout())
      .toList();

  @override
  bool shouldRepaint(_StampPainter oldDelegate) =>
      oldDelegate.seed != seed ||
      oldDelegate.shape != shape ||
      oldDelegate.font != font ||
      oldDelegate.countryName != countryName ||
      oldDelegate.dateLabel != dateLabel ||
      oldDelegate.daysLabel != daysLabel ||
      oldDelegate.color != color;
}
