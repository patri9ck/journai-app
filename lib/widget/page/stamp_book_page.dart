// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Patrick Zwick

import 'package:flutter/material.dart';

import '../../messages/app_localizations.dart';
import '../../model/day_weather.dart';
import '../../model/trip.dart';
import '../../util/trip_memories.dart';
import '../shared/share_image.dart';
import '../shared/travel_stamp.dart';

class StampBookPage extends StatelessWidget {
  final List<Trip> trips;
  final Map<int, Map<DateTime, DayWeather>> weather;

  const StampBookPage({super.key, required this.trips, required this.weather});

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final now = DateTime.now();
    final stampedTrips = trips.where((trip) => !trip.start.isAfter(now)).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(localizations.memoriesStampBook),
        actions: [
          if (stampedTrips.isNotEmpty)
            IconButton(
              tooltip: localizations.share,
              icon: const Icon(Icons.share_outlined),
              onPressed: () => shareWidgetAsImage(
                context,
                fileName: 'stamp_book',
                subject: localizations.memoriesStampBook,
                child: SharePoster(
                  title: localizations.memoriesStampBook,
                  child: _StampPage(trips: stampedTrips, weather: weather),
                ),
              ),
            ),
        ],
      ),
      body: stampedTrips.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(localizations.stampBookEmpty, textAlign: TextAlign.center),
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF3EEDF),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: _StampPage(trips: stampedTrips, weather: weather),
              ),
            ),
    );
  }
}

class _StampPage extends StatelessWidget {
  final List<Trip> trips;
  final Map<int, Map<DateTime, DayWeather>> weather;

  const _StampPage({required this.trips, required this.weather});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final trip in trips)
          TravelStamp(trip: trip, temperature: averageTemperature(weather[trip.id] ?? {}), size: 140),
      ],
    );
  }
}
