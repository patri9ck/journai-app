// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Patrick Zwick

import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../messages/app_localizations.dart';
import '../../model/data.dart';
import '../../model/day_weather.dart';
import '../../model/journal_entry.dart';
import '../../model/limits.dart';
import '../../model/poster_style.dart';
import '../../model/result.dart';
import '../../model/time_capsule.dart';
import '../../model/trip.dart';
import '../../service/services.dart';
import '../../util/country_name.dart';
import '../../util/temperature_format.dart';
import '../../util/trip_memories.dart';
import '../../util/units_notifier.dart';
import '../sheet/journal_entry_sheet.dart';
import '../sheet/location_sheet.dart';
import '../sheet/paywall_sheet.dart';
import '../sheet/poster_style_sheet.dart';
import '../shared/document_shared.dart';
import '../shared/share_image.dart';
import '../shared/travel_stamp.dart';
import '../shared/trip_stripes.dart';
import '../sheet/stamp_style_sheet.dart';
import 'entry_check_page.dart';
import 'time_capsule_page.dart';

class TripPage extends StatefulWidget {
  final Trip trip;

  const TripPage({super.key, required this.trip});

  @override
  State<TripPage> createState() => _TripPageState();
}

class _TripPageState extends State<TripPage> {
  late Trip _trip = widget.trip;
  List<Data> _data = [];
  Map<DateTime, DayWeather> _weather = {};
  Limits _limits = Limits.unlimited;
  late int _selectedDay = _initialDay();
  bool _playing = false;
  StreamSubscription<void>? _playerCompletion;

  @override
  void initState() {
    super.initState();
    _playerCompletion = soundService.onPlayerComplete.listen((_) {
      if (mounted) {
        setState(() => _playing = false);
      }
    });
    _load();
  }

  @override
  void dispose() {
    _playerCompletion?.cancel();
    soundService.stop();
    super.dispose();
  }

  int _initialDay() {
    final now = DateTime.now();
    final index = _trip.days.indexOf(DateTime(now.year, now.month, now.day));

    return index == -1 ? 0 : index;
  }

  Future<void> _load() async {
    final data = await dataService.getCachedData();
    final limits = await limitsService.getCachedLimits();

    if (!mounted) {
      return;
    }

    setState(() {
      _data = data;
      _limits = limits;
    });

    final cachedWeather = await getCachedTripWeather(_trip);

    if (!mounted) {
      return;
    }

    setState(() => _weather = cachedWeather);

    final result = await dataService.getData();

    if (!mounted) {
      return;
    }

    if (result is Success<List<Data>>) {
      setState(() => _data = result.value ?? []);
    }

    final weather = await loadTripWeather(_trip);

    if (mounted) {
      setState(() => _weather = weather);
    }
  }

  List<JournalEntry> get _entries => JournalEntry.fromDataList(_data, _trip.id!);

  TimeCapsule? get _timeCapsule =>
      TimeCapsule.fromDataList(_data).where((timeCapsule) => timeCapsule.tripId == _trip.id).firstOrNull;

  String _temperature(AppLocalizations localizations, DayWeather dayWeather) =>
      formatTemperature(localizations, dayWeather.temperature, metricUnits: metricUnitsNotifier.value);

  JournalEntry? _entryOn(DateTime day) => _entries.where((entry) => entry.date == day).firstOrNull;

  Future<void> _changeDates() async {
    final now = DateTime.now();

    final dates = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(now.year + 2, now.month, now.day),
      initialDateRange: DateTimeRange(start: _trip.start, end: _trip.end),
    );

    if (dates == null || !mounted) {
      return;
    }

    final trip = _trip.copyWith(start: dates.start, end: dates.end);

    final saved = await ensureAndSave(
      context,
      () => dataService.updateData(trip.id!, Data(feature: 'TRIP', fields: trip.toFields())),
    );

    if (!saved || !mounted) {
      return;
    }

    setState(() {
      _trip = trip;
      _selectedDay = _initialDay();
    });

    await _load();
  }

  Future<void> _delete() async {
    final localizations = AppLocalizations.of(context)!;

    final confirmed = await confirmDelete(
      context,
      localizations.tripDeleteConfirm,
      localizations.documentDeleteConfirmYes,
    );

    if (!confirmed || !mounted) {
      return;
    }

    final result = await deleteTripWithMemories(_trip, _data);

    if (!mounted) {
      return;
    }

    if (result is Failure<void>) {
      result.show(localizations);

      return;
    }

    Navigator.of(context).pop();
  }

  Future<void> _openEntryCheck() async {
    if (!_limits.isFeatureEnabled('ENTRY_CHECK')) {
      await showPaywall(context);

      return;
    }

    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => EntryCheckPage(data: _data, trip: _trip)));
  }

  Future<void> _changeLocation() async {
    final city = await showLocationSheet(context, _trip.city);

    if (city == null || !mounted) {
      return;
    }

    final trip = _trip.copyWith(city: city);

    final saved = await ensureAndSave(
      context,
      () => dataService.updateData(trip.id!, Data(feature: 'TRIP', fields: trip.toFields())),
    );

    if (!saved) {
      return;
    }

    await dataService.getData();

    if (mounted) {
      setState(() => _trip = trip);
    }
  }

  Future<void> _customizeStamp() async {
    final trip = await showModalBottomSheet<Trip>(
      context: context,
      isScrollControlled: true,
      builder: (_) => StampStyleSheet(trip: _trip, temperature: averageTemperature(_weather)),
    );

    if (trip == null || !mounted) {
      return;
    }

    setState(() => _trip = trip);
  }

  Future<void> _editEntry(DateTime day) async {
    if (!_limits.isFeatureEnabled('JOURNAL_ENTRY')) {
      await showPaywall(context);

      return;
    }

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => JournalEntrySheet(tripId: _trip.id!, date: day, entry: _entryOn(day)),
    );

    if (saved == true) {
      await _load();
    }
  }

  Future<void> _toggleSound(String sound) async {
    if (_playing) {
      await soundService.stop();
      setState(() => _playing = false);

      return;
    }

    setState(() => _playing = true);
    await soundService.play(sound);
  }

  Future<void> _openTimeCapsule() async {
    final timeCapsule = _timeCapsule;

    if (timeCapsule == null && !_limits.isFeatureEnabled('TIME_CAPSULE')) {
      await showPaywall(context);

      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => TimeCapsulePage(trip: _trip, timeCapsule: timeCapsule, temperature: averageTemperature(_weather))),
    );

    await _load();
  }

  Future<void> _shareTrip(AppLocalizations localizations) => shareWidgetAsImage(
    context,
    fileName: 'trip',
    subject: tripPlaceName(context, _trip),
    child: SharePoster(
      title: tripPlaceName(context, _trip),
      subtitle: _dateRange(localizations),
      child: Column(
        children: [
          TravelStamp(trip: _trip, temperature: averageTemperature(_weather), size: 160),
          const SizedBox(height: 20),
          TripStripes(stripes: tripStripes(_trip, _weather), height: 72),
        ],
      ),
    ),
  );

  Future<void> _shareAlbum(AppLocalizations localizations, List<Data> album) async {
    await Future.wait([
      for (final image in album.map(albumImage).whereType<ImageProvider>()) precacheImage(image, context),
    ]);

    if (!mounted) {
      return;
    }

    await shareWidgetAsImage(
      context,
      fileName: 'scrapbook',
      subject: localizations.tripAlbumTitle,
      child: SharePoster(
        title: localizations.tripAlbumTitle,
        subtitle: tripPlaceName(context, _trip),
        style: _trip.albumStyle,
        child: _Album(items: album),
      ),
    );
  }

  Future<void> _customizeAlbum() async {
    final localizations = AppLocalizations.of(context)!;

    final style = await showModalBottomSheet<PosterStyle>(
      context: context,
      isScrollControlled: true,
      builder: (_) => PosterStyleSheet(
        title: localizations.tripAlbumCustomize,
        defaultHeading: localizations.tripAlbumTitle,
        style: _trip.albumStyle,
      ),
    );

    if (style == null || !mounted) {
      return;
    }

    final trip = _trip.copyWith(albumStyle: style);

    final saved = await ensureAndSave(
      context,
      () => dataService.updateData(trip.id!, Data(feature: 'TRIP', fields: trip.toFields())),
    );

    if (!saved) {
      return;
    }

    await dataService.getData();

    if (mounted) {
      setState(() => _trip = trip);
    }
  }

  String _dateRange(AppLocalizations localizations) {
    final dateFormat = DateFormat.yMMMd(localizations.localeName);

    return '${dateFormat.format(_trip.start)} - ${dateFormat.format(_trip.end)} · ${localizations.tripDays(_trip.days.length)}';
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final mutedColor = theme.colorScheme.onSurface.withValues(alpha: 0.6);
    final days = _trip.days;
    final day = days[_selectedDay.clamp(0, days.length - 1)];
    final entry = _entryOn(day);
    final dayWeather = _weather[day];
    final album = tripAlbum(_trip, _data);
    final timeCapsule = _timeCapsule;
    final memoryDays = _entries.map((entry) => entry.date).toSet();

    return Scaffold(
      appBar: AppBar(
        title: Text(tripPlaceName(context, _trip)),
        actions: [
          IconButton(
            tooltip: localizations.share,
            icon: const Icon(Icons.share_outlined),
            onPressed: () => _shareTrip(localizations),
          ),
          PopupMenuButton<VoidCallback>(
            key: const ValueKey('trip_menu'),
            onSelected: (action) => action(),
            itemBuilder: (_) => [
              PopupMenuItem(value: _customizeStamp, child: Text(localizations.stampCustomize)),
              PopupMenuItem(value: _changeLocation, child: Text(localizations.tripChangeLocation)),
              PopupMenuItem(value: _changeDates, child: Text(localizations.tripChangeDates)),
              PopupMenuItem(value: _delete, child: Text(localizations.tripDelete)),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
        children: [
          Center(
            child: GestureDetector(
              onTap: _customizeStamp,
              child: TravelStamp(trip: _trip, temperature: averageTemperature(_weather), size: 150),
            ),
          ),
          const SizedBox(height: 8),
          Center(child: Text(_dateRange(localizations), style: theme.textTheme.bodyMedium?.copyWith(color: mutedColor))),
          const SizedBox(height: 12),
          Center(
            child: OutlinedButton.icon(
              onPressed: _openEntryCheck,
              icon: const Icon(Icons.fact_check_outlined, size: 18),
              label: Text(localizations.entryCheckTitle),
            ),
          ),
          const SizedBox(height: 24),
          Text(localizations.tripStripesTitle, style: theme.textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(localizations.tripStripesLegend, style: theme.textTheme.bodySmall?.copyWith(color: mutedColor)),
          const SizedBox(height: 12),
          TripStripes(
            stripes: tripStripes(_trip, _weather, memoryDays: memoryDays),
            height: 96,
            selectedIndex: _selectedDay,
            onSelected: (index) => setState(() => _selectedDay = index),
          ),
          const SizedBox(height: 12),
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    localizations.tripDayTitle(_selectedDay + 1, DateFormat.MMMMEEEEd(localizations.localeName).format(day)),
                    style: theme.textTheme.titleSmall,
                  ),
                  if (dayWeather != null)
                    Text(
                      dayWeather.isRainy
                          ? localizations.tripDayWeatherRainy(_temperature(localizations, dayWeather))
                          : _temperature(localizations, dayWeather),
                      style: theme.textTheme.bodySmall?.copyWith(color: mutedColor),
                    ),
                  const SizedBox(height: 12),
                  Text(
                    entry == null || entry.text.isEmpty ? localizations.tripDayNoEntry : entry.text,
                    style: entry == null || entry.text.isEmpty
                        ? theme.textTheme.bodyMedium?.copyWith(color: mutedColor)
                        : theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (entry?.sound case final String sound)
                        FilledButton.tonalIcon(
                          onPressed: () => _toggleSound(sound),
                          icon: Icon(_playing ? Icons.stop : Icons.graphic_eq, size: 18),
                          label: Text(localizations.journalEntryPlaySound),
                        ),
                      OutlinedButton.icon(
                        onPressed: () => _editEntry(day),
                        icon: const Icon(Icons.edit_outlined, size: 18),
                        label: Text(entry == null ? localizations.tripDayWrite : localizations.tripDayEdit),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          PosterCard(
            title: localizations.tripAlbumTitle,
            subtitle: tripPlaceName(context, _trip),
            style: _trip.albumStyle,
            customizeTooltip: localizations.tripAlbumCustomize,
            onCustomize: _customizeAlbum,
            onShare: album.isEmpty ? null : () => _shareAlbum(localizations, album),
            child: album.isEmpty
                ? Text(localizations.tripAlbumEmpty, style: theme.textTheme.bodySmall?.copyWith(color: sharePosterSubtitleColor))
                : _Album(items: album),
          ),
          const SizedBox(height: 24),
          Text(localizations.tripTimeCapsuleTitle, style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Card(
            margin: EdgeInsets.zero,
            child: ListTile(
              leading: Icon(timeCapsule == null ? Icons.edit_note : Icons.mark_email_unread_outlined),
              title: Text(
                timeCapsule == null
                    ? localizations.tripTimeCapsuleWrite
                    : localizations.tripTimeCapsuleOpensOn(DateFormat.yMMMd(localizations.localeName).format(timeCapsule.opensAt)),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: _openTimeCapsule,
            ),
          ),
        ],
      ),
    );
  }
}

class _Album extends StatelessWidget {
  final List<Data> items;

  const _Album({required this.items});

  static const _spacing = 12.0;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = min(150.0, (constraints.maxWidth - _spacing) / 2);

        return Wrap(
          spacing: _spacing,
          runSpacing: 16,
          children: [
            for (final item in items) _AlbumItem(key: ValueKey(item.id), item: item, width: width),
          ],
        );
      },
    );
  }
}

class _AlbumItem extends StatelessWidget {
  final Data item;
  final double width;

  const _AlbumItem({super.key, required this.item, required this.width});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final image = albumImage(item);
    const paperColor = Color(0xFFFBF6EA);
    const inkColor = Color(0xFF3A3A3A);

    return Transform.rotate(
      angle: ((item.id ?? 0) % 7 - 3) * 0.02,
      child: Container(
        width: width,
        padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
        decoration: BoxDecoration(
          color: paperColor,
          borderRadius: BorderRadius.circular(4),
          boxShadow: const [BoxShadow(color: Color(0x22000000), blurRadius: 6, offset: Offset(0, 2))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (image != null) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: Image(image: image, height: width * 2 / 3, width: double.infinity, fit: BoxFit.cover),
              ),
              const SizedBox(height: 8),
            ] else ...[
              Icon(
                switch (item.feature) {
                  'TICKET' => Icons.confirmation_number_outlined,
                  'IMAGE' => Icons.photo_outlined,
                  _ => Icons.receipt_long_outlined,
                },
                size: 18,
                color: inkColor,
              ),
              const SizedBox(height: 6),
            ],
            Text(
              (item.fields['title'] ?? item.fields['merchant'] ?? item.fields['comment'] ?? '') as String,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium?.copyWith(color: inkColor, fontWeight: FontWeight.w600),
            ),
            Text(
              [
                item.fields['date'],
                if (item.fields['amount'] != null) '${item.fields['amount']} ${item.fields['currency'] ?? ''}'.trim(),
              ].join(' · '),
              style: theme.textTheme.bodySmall?.copyWith(color: inkColor),
            ),
          ],
        ),
      ),
    );
  }
}
