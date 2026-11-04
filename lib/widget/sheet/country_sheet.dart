// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Patrick Zwick

import 'package:flutter/material.dart';

import '../../messages/app_localizations.dart';
import '../../util/country_data.dart';
import '../shared/sheet_handle.dart';

Future<String?> showCountrySheet(BuildContext context, {Set<String> excludedCountryCodes = const {}}) =>
    showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _CountrySheet(excludedCountryCodes: excludedCountryCodes),
    );

class _CountrySheet extends StatefulWidget {
  final Set<String> excludedCountryCodes;

  const _CountrySheet({required this.excludedCountryCodes});

  @override
  State<_CountrySheet> createState() => _CountrySheetState();
}

class _CountrySheetState extends State<_CountrySheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final languageCode = Localizations.localeOf(context).languageCode;
    final query = _query.trim().toLowerCase();
    final countries = [
      for (final countryCode in countryCodes)
        if (!widget.excludedCountryCodes.contains(countryCode)) (countryCode, countryName(countryCode, languageCode)),
    ].where((country) => query.isEmpty || country.$2.toLowerCase().contains(query)).toList()
      ..sort((first, second) => first.$2.compareTo(second.$2));

    return DraggableScrollableSheet(
      initialChildSize: 0.92,
      minChildSize: 0.5,
      maxChildSize: 1.0,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            const SheetHandle(),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: TextField(
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  hintText: localizations.countrySearchHint,
                  prefixIcon: const Icon(Icons.search),
                ),
                onChanged: (query) => setState(() => _query = query),
              ),
            ),
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                itemCount: countries.length,
                itemBuilder: (context, index) {
                  final (countryCode, name) = countries[index];

                  return ListTile(
                    leading: Text(countryFlag(countryCode), style: const TextStyle(fontSize: 24)),
                    title: Text(name),
                    onTap: () => Navigator.of(context).pop(countryCode),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}
