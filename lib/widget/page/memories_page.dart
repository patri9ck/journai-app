// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Patrick Zwick

import 'package:country_picker/country_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../messages/app_localizations.dart';
import '../../model/data.dart';
import '../../model/day_weather.dart';
import '../../model/limits.dart';
import '../../model/result.dart';
import '../../model/trip.dart';
import '../../service/services.dart';
import '../../util/auth_scope.dart';
import '../../util/country_name.dart';
import '../../util/document_date.dart';
import '../../util/trip_memories.dart';
import '../sheet/paywall_sheet.dart';
import '../shared/document_shared.dart';
import '../shared/empty_state.dart';
import '../shared/share_image.dart';
import '../shared/travel_stamp.dart';
import '../shared/trip_stripes.dart';
import 'stamp_book_page.dart';
import 'trip_page.dart';

class MemoriesPage extends StatefulWidget {
  const MemoriesPage({super.key});

  @override
  State<MemoriesPage> createState() => _MemoriesPageState();
}

class _MemoriesPageState extends State<MemoriesPage> {
  List<Data> _data = [];
  List<Trip> _trips = [];
  Map<int, Map<DateTime, DayWeather>> _weather = {};
  Limits _limits = Limits.unlimited;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final data = await dataService.getCachedData();
    final limits = await limitsService.getCachedLimits();

    if (!mounted) {
      return;
    }

    setState(() {
      _data = data;
      _trips = Trip.fromDataList(data);
      _limits = limits;
    });

    final result = await dataService.getData();

    if (!mounted || result is! Success<List<Data>>) {
      return;
    }

    setState(() {
      _data = result.value ?? [];
      _trips = Trip.fromDataList(_data);
    });

    for (final trip in _trips) {
      final weather = await loadTripWeather(trip);

      if (!mounted) {
        return;
      }

      setState(() => _weather = {..._weather, trip.id!: weather});
    }
  }

  void _add() {
    final tripLimit = _limits.features['TRIP'];

    if (tripLimit != null && tripLimit != -1 && _trips.length >= tripLimit) {
      showPaywall(context);

      return;
    }

    Country? selectedCountry;

    showCountryPicker(
      context: context,
      showPhoneCode: false,
      onSelect: (country) => selectedCountry = country,
      onClosed: () async {
        final country = selectedCountry;

        if (country == null) {
          return;
        }

        final now = DateTime.now();

        final dates = await showDateRangePicker(
          context: context,
          firstDate: DateTime(2000),
          lastDate: DateTime(now.year + 2, now.month, now.day),
        );

        if (dates == null || !mounted) {
          return;
        }

        final countryName =
            CountryLocalizations.of(context)?.countryName(countryCode: country.countryCode) ?? country.name;

        final trip = Trip(
          countryCode: country.countryCode,
          countryName: countryName,
          start: dates.start,
          end: dates.end,
        );

        final saved = await ensureAndSave(
          context,
          () => dataService.saveData(Data(feature: 'TRIP', fields: trip.toFields())),
        );

        if (saved) {
          await _load();
        }
      },
    );
  }

  Future<void> _open(Trip trip) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => TripPage(trip: trip)));
    await _load();
  }

  bool _passportExpiresDuring(Trip trip) {
    final expiryDates = _data
        .where((data) => data.feature == 'PASSPORT')
        .map((data) => parseDocumentDate(data.fields['expiryDate'] as String?))
        .whereType<DateTime>();

    return expiryDates.isNotEmpty && expiryDates.every((expiryDate) => expiryDate.isBefore(trip.end));
  }

  Future<void> _shareLifeBand(AppLocalizations localizations) => shareWidgetAsImage(
    context,
    fileName: 'life_band',
    subject: localizations.memoriesLifeBand,
    child: SharePoster(
      title: localizations.memoriesLifeBand,
      subtitle: localizations.memoriesLifeBandHint,
      child: _LifeBand(trips: _trips, weather: _weather, labelColor: sharePosterSubtitleColor),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final dateFormat = DateFormat.yMd(localizations.localeName);
    final isLoggedIn = AuthScope.of(context);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    return Scaffold(
      appBar: AppBar(
        title: Text(localizations.memoriesTitle),
        actions: [
          if (_trips.isNotEmpty) ...[
            IconButton(
              tooltip: localizations.memoriesStampBook,
              icon: const Icon(Icons.auto_stories_outlined),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => StampBookPage(trips: _trips, weather: _weather)),
              ),
            ),
            IconButton(
              tooltip: localizations.share,
              icon: const Icon(Icons.share_outlined),
              onPressed: () => _shareLifeBand(localizations),
            ),
          ],
        ],
      ),
      floatingActionButton: isLoggedIn
          ? FloatingActionButton.extended(onPressed: _add, icon: const Icon(Icons.add), label: Text(localizations.tripAdd))
          : null,
      body: _trips.isEmpty
          ? EmptyState(
              icon: Icons.luggage_outlined,
              title: localizations.memoriesEmpty,
              text: isLoggedIn ? localizations.memoriesHint : localizations.loginRequiredForFeature,
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
              children: [
                Text(localizations.memoriesLifeBand, style: theme.textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(
                  localizations.memoriesLifeBandHint,
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
                ),
                const SizedBox(height: 12),
                _LifeBand(trips: _trips, weather: _weather, onOpen: _open),
                const SizedBox(height: 24),
                for (final trip in _trips.reversed)
                  Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: () => _open(trip),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            TravelStamp(trip: trip, temperature: averageTemperature(_weather[trip.id] ?? {}), size: 80),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(tripCountryName(context, trip), style: theme.textTheme.titleMedium),
                                  Text('${dateFormat.format(trip.start)} - ${dateFormat.format(trip.end)}'),
                                  if (!trip.isOver(today) && _passportExpiresDuring(trip))
                                    Text(localizations.tripPassportExpires, style: TextStyle(color: Colors.red.shade600)),
                                  const SizedBox(height: 8),
                                  TripStripes(stripes: tripStripes(trip, _weather[trip.id] ?? {}), height: 22, spacing: 2),
                                ],
                              ),
                            ),
                            const Icon(Icons.chevron_right),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}

class _LifeBand extends StatelessWidget {
  final List<Trip> trips;
  final Map<int, Map<DateTime, DayWeather>> weather;
  final ValueChanged<Trip>? onOpen;
  final Color? labelColor;

  const _LifeBand({required this.trips, required this.weather, this.onOpen, this.labelColor});

  static const _dayWidth = 9.0;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final labelFormat = DateFormat.yMMM(localizations.localeName);

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        for (final trip in trips)
          GestureDetector(
            onTap: onOpen == null ? null : () => onOpen!(trip),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: trip.days.length * _dayWidth,
                  child: TripStripes(stripes: tripStripes(trip, weather[trip.id] ?? {}), height: 56, spacing: 2),
                ),
                const SizedBox(height: 4),
                Text(
                  '${trip.countryCode} · ${labelFormat.format(trip.start)}',
                  style: theme.textTheme.labelSmall?.copyWith(color: labelColor ?? theme.colorScheme.onSurface.withValues(alpha: 0.6)),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
