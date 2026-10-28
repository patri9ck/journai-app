// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Patrick Zwick

import 'package:flutter/material.dart';

import '../../messages/app_localizations.dart';
import '../../service/services.dart';
import '../../util/country_data.dart';
import '../../util/country_name.dart';
import '../shared/empty_state.dart';
import '../sheet/country_sheet.dart';

class TravelWarningAlertPage extends StatefulWidget {
  const TravelWarningAlertPage({super.key});

  @override
  State<TravelWarningAlertPage> createState() => _TravelWarningAlertPageState();
}

class _TravelWarningAlertPageState extends State<TravelWarningAlertPage> {
  List<String> _countries = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final countries = await travelWarningAlertService.getWatchedCountries();

    if (mounted) {
      setState(() => _countries = countries);
    }
  }

  Future<void> _addCountry() async {
    final countryCode = await showCountrySheet(
      context,
      excludedCountryCodes: {
        for (final entry in iso2ToIso3.entries)
          if (_countries.contains(entry.value)) entry.key,
      },
    );

    if (countryCode == null) {
      return;
    }

    await _watch(iso2ToIso3[countryCode]);
  }

  Future<void> _watch(String? countryCode) async {
    if (countryCode == null) {
      return;
    }

    final localizations = AppLocalizations.of(context)!;
    final watched = await travelWarningAlertService.watch(countryCode);

    if (!mounted) {
      return;
    }

    if (!watched) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(localizations.settingsNotificationPermissionDenied, textAlign: TextAlign.center)),
      );

      return;
    }

    await _load();
  }

  Future<void> _unwatch(String countryCode) async {
    await travelWarningAlertService.unwatch(countryCode);

    await _load();
  }

  String _countryName(String countryCode) {
    final iso2CountryCode = iso2ToIso3.entries
        .firstWhere((entry) => entry.value == countryCode, orElse: () => MapEntry(countryCode, countryCode))
        .key;

    return localizedCountryName(context, iso2CountryCode);
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(localizations.travelWarningAlertsTitle)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addCountry,
        icon: const Icon(Icons.add),
        label: Text(localizations.travelWarningAlertsAdd),
      ),
      body: _countries.isEmpty
          ? EmptyState(
              icon: Icons.notifications_none_outlined,
              title: localizations.travelWarningAlertsEmpty,
              text: localizations.travelWarningAlertsHint,
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
              children: [
                Text(
                  localizations.travelWarningAlertsHint,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
                const SizedBox(height: 16),
                for (final countryCode in _countries)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.notifications_active_outlined),
                    title: Text(_countryName(countryCode)),
                    trailing: IconButton(
                      icon: const Icon(Icons.close),
                      tooltip: localizations.travelWarningAlertsRemove,
                      onPressed: () => _unwatch(countryCode),
                    ),
                  ),
              ],
            ),
    );
  }
}
