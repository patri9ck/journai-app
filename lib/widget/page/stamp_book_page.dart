// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Patrick Zwick

import 'dart:math';

import 'package:flutter/material.dart';

import '../../messages/app_localizations.dart';
import '../../model/day_weather.dart';
import '../../model/stamp_book_style.dart';
import '../../model/trip.dart';
import '../../util/cache.dart';
import '../../util/trip_memories.dart';
import '../sheet/stamp_book_style_sheet.dart';
import '../shared/empty_state.dart';
import '../shared/share_image.dart';
import '../shared/travel_stamp.dart';

class StampBookPage extends StatefulWidget {
  final List<Trip> trips;
  final Map<int, Map<DateTime, DayWeather>> weather;

  const StampBookPage({super.key, required this.trips, required this.weather});

  @override
  State<StampBookPage> createState() => _StampBookPageState();
}

class _StampBookPageState extends State<StampBookPage> {
  static const _styleKey = 'settings_stamp_book';

  StampBookStyle _style = const StampBookStyle();

  @override
  void initState() {
    super.initState();
    _loadStyle();
  }

  Future<void> _loadStyle() async {
    final json = await readObjectCache(_styleKey);

    if (json == null || !mounted) {
      return;
    }

    setState(() => _style = StampBookStyle.fromJson(json));
  }

  Future<void> _customize() async {
    final style = await showModalBottomSheet<StampBookStyle>(
      context: context,
      isScrollControlled: true,
      builder: (_) => StampBookStyleSheet(style: _style),
    );

    if (style == null || !mounted) {
      return;
    }

    setState(() => _style = style);

    await saveObjectCache(_styleKey, style.toJson());
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final trips = widget.trips;

    return Scaffold(
      appBar: AppBar(
        title: Text(localizations.memoriesStampBook),
        actions: [
          if (trips.isNotEmpty) ...[
            IconButton(
              tooltip: localizations.stampBookCustomize,
              icon: const Icon(Icons.palette_outlined),
              onPressed: _customize,
            ),
            IconButton(
              tooltip: localizations.share,
              icon: const Icon(Icons.share_outlined),
              onPressed: () => shareWidgetAsImage(
                context,
                fileName: 'stamp_book',
                subject: localizations.memoriesStampBook,
                child: SharePoster(
                  title: localizations.memoriesStampBook,
                  child: _StampPage(trips: trips, weather: widget.weather, style: _style),
                ),
              ),
            ),
          ],
        ],
      ),
      body: trips.isEmpty
          ? EmptyState(icon: Icons.auto_stories_outlined, text: localizations.stampBookEmpty)
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: _StampPage(trips: trips, weather: widget.weather, style: _style),
            ),
    );
  }
}

class _StampPage extends StatelessWidget {
  final List<Trip> trips;
  final Map<int, Map<DateTime, DayWeather>> weather;
  final StampBookStyle style;

  const _StampPage({required this.trips, required this.weather, required this.style});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final frameColor = Color.lerp(style.background, const Color(0xFF14161B), 0.45)!;
    final scattered = style.layout == StampBookLayout.scattered;

    final stamps = Wrap(
      alignment: WrapAlignment.center,
      spacing: scattered ? 0 : 8,
      runSpacing: scattered ? 0 : 8,
      children: [
        for (final trip in trips)
          _placed(
            trip,
            scattered,
            Opacity(
              opacity: trip.start.isAfter(now) ? 0.5 : 1,
              child: TravelStamp(trip: trip, temperature: averageTemperature(weather[trip.id] ?? {}), size: style.stampSize),
            ),
          ),
      ],
    );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: style.background,
        borderRadius: BorderRadius.circular(8),
        border: style.frame == StampBookFrame.none ? null : Border.all(color: frameColor, width: 2),
      ),
      child: style.frame == StampBookFrame.double
          ? Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: frameColor, width: 1),
              ),
              child: stamps,
            )
          : stamps,
    );
  }

  Widget _placed(Trip trip, bool scattered, Widget stamp) {
    if (!scattered) {
      return stamp;
    }

    final random = Random(trip.id ?? trip.countryCode.hashCode);

    return Transform.translate(
      offset: Offset((random.nextDouble() - 0.5) * 16, (random.nextDouble() - 0.5) * 16),
      child: Transform.rotate(angle: (random.nextDouble() - 0.5) * 0.6, child: stamp),
    );
  }
}
