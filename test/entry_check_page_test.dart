// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Patrick Zwick

import 'package:country_picker/country_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:journai_app/messages/app_localizations.dart';
import 'package:journai_app/model/trip.dart';
import 'package:journai_app/widget/page/entry_check_page.dart';

void main() {
  final start = DateTime.now().add(const Duration(days: 30));

  Widget app() => MaterialApp(
    locale: const Locale('en'),
    localizationsDelegates: const [...AppLocalizations.localizationsDelegates, CountryLocalizations.delegate],
    supportedLocales: AppLocalizations.supportedLocales,
    home: EntryCheckPage(
      data: const [],
      trip: Trip(
        id: 1,
        countryCode: 'TH',
        countryName: 'Thailand',
        start: DateTime(start.year, start.month, start.day),
        end: DateTime(start.year, start.month, start.day + 14),
      ),
    ),
  );

  testWidgets('shows the trip without managing it', (tester) async {
    await tester.pumpWidget(app());
    await tester.pump();

    expect(find.text('Thailand'), findsOneWidget);
    expect(find.byType(FloatingActionButton), findsNothing);
    expect(find.byKey(const ValueKey('trip_menu')), findsNothing);
  });
}
