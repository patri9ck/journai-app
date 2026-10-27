// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Patrick Zwick

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:journai_app/main.dart' as app;
import 'package:journai_app/model/trip.dart';
import 'package:journai_app/service/services.dart';
import 'package:journai_app/util/navigator_key.dart';
import 'package:journai_app/widget/page/data_page.dart';
import 'package:journai_app/widget/page/entry_check_page.dart';

import 'support.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(seedDemoData);

  testWidgets('encrypted data is decrypted and shown offline', (tester) async {
    app.main();
    app.screenshotLocaleNotifier.value = const Locale('en');

    expect(
      await waitFor(tester, find.byKey(const ValueKey('emergency_card_preview')), timeout: const Duration(seconds: 30)),
      isTrue,
    );
    expect(await waitFor(tester, find.text('2 allergies - 0 conditions - 4 vaccinations')), isTrue);

    await tester.tap(find.byKey(const ValueKey('tab_data')));
    await pumpFor(tester, const Duration(seconds: 1));
    await tester.tap(find.byKey(const ValueKey('data_vaccinations')));

    expect(await waitFor(tester, find.text('Hepatitis A (Havrix)')), isTrue);

    await back(tester);

    navigatorKey.currentState!.push(
      MaterialPageRoute(
        builder: (_) => EntryCheckPage(
          data: [],
          trip: Trip(
            countryCode: 'TH',
            countryName: 'Thailand',
            start: tripStart,
            end: tripStart.add(const Duration(days: 14)),
          ),
        ),
      ),
    );

    expect(await waitFor(tester, find.text('Vaccination plan')), isTrue);

    await back(tester);
    expect(await dataService.getCachedData(['PROFILE']), isEmpty);

    await tester.tap(find.byKey(const ValueKey('tab_home')));
    await pumpFor(tester, const Duration(seconds: 1));

    final tripsCard = find.byKey(const ValueKey('trips_card'));

    expect(await waitFor(tester, find.textContaining('Thailand')), isTrue);

    await tester.tap(tripsCard);

    expect(await waitFor(tester, find.text('Add trip')), isTrue);
    expect(find.text('Your passport expires before the end of the trip.'), findsNothing);

    await back(tester);

    await tester.tap(find.byKey(const ValueKey('tab_data')));
    await pumpFor(tester, const Duration(seconds: 1));
    await tester.scrollUntilVisible(
      find.text('Medical receipts'),
      200,
      scrollable: find.descendant(of: find.byType(DataPage), matching: find.byType(Scrollable)).first,
    );
    await tester.tap(find.text('Medical receipts'));

    expect(await waitFor(tester, find.text('Bangkok Hospital')), isTrue);
    expect(await waitFor(tester, find.text('Total in euros')), isTrue);
  });
}
