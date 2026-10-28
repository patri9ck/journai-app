// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Patrick Zwick

import 'package:country_picker/country_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:journai_app/messages/app_localizations.dart';
import 'package:journai_app/model/trip.dart';
import 'package:journai_app/widget/page/trip_page.dart';

void main() {
  final start = DateTime.now().add(const Duration(days: 30));

  Widget app() => MaterialApp(
    locale: const Locale('en'),
    localizationsDelegates: const [...AppLocalizations.localizationsDelegates, CountryLocalizations.delegate],
    supportedLocales: AppLocalizations.supportedLocales,
    home: TripPage(
      trip: Trip(
        id: 1,
        countryCode: 'TH',
        countryName: 'Thailand',
        start: DateTime(start.year, start.month, start.day),
        end: DateTime(start.year, start.month, start.day + 14),
      ),
    ),
  );

  Future<void> settle(WidgetTester tester) async {
    for (var frame = 0; frame < 10; frame++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  testWidgets('shows the trip with its memories and offers changing its dates or deleting it', (tester) async {
    await tester.pumpWidget(app());
    await settle(tester);

    expect(find.text('Thailand'), findsOneWidget);
    expect(find.text('Travel Stripes'), findsOneWidget);
    expect(find.text('Entry Check'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('trip_menu')));
    await settle(tester);

    expect(find.text('Change dates'), findsOneWidget);
    expect(find.text('Delete trip'), findsOneWidget);

    await tester.tap(find.text('Change dates'));
    await settle(tester);

    expect(find.byType(DateRangePickerDialog), findsOneWidget);
  });
}
