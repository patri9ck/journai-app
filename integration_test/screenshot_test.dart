// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Patrick Zwick

import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:journai_app/main.dart' as app;
import 'package:journai_app/model/trip.dart';
import 'package:journai_app/service/services.dart';
import 'package:journai_app/util/navigator_key.dart';
import 'package:journai_app/widget/page/entry_check_page.dart';
import 'package:journai_app/widget/page/full_map_page.dart';

import 'support.dart';

const _langs = ['en', 'de'];

final _screenshots = <String, String>{};

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(seedDemoData);

  testWidgets('marketing screenshots', (tester) async {
    app.main();
    await waitFor(tester, find.byKey(const ValueKey('emergency_card_preview')), timeout: const Duration(seconds: 30));
    await pumpFor(tester, const Duration(seconds: 2));

    for (final lang in _langs) {
      app.screenshotLocaleNotifier.value = Locale(lang);
      await pumpFor(tester, const Duration(seconds: 2));

      await _save(tester, lang, '01_dashboard');

      final emergencyCardFinder = find.byKey(const ValueKey('emergency_card_preview'));

      if (await waitFor(tester, emergencyCardFinder)) {
        await tester.tap(emergencyCardFinder);
        await pumpFor(tester, const Duration(seconds: 2));
        await _save(tester, lang, '02_emergency_card');
        await back(tester);
      }

      navigatorKey.currentState!.push(MaterialPageRoute(builder: (_) => FullMapPage(position: LatLng(parisPosition().latitude, parisPosition().longitude))));
      await pumpFor(tester, const Duration(seconds: 8));
      await _save(tester, lang, '03_full_map');
      await back(tester);

      final locationHeaderFinder = find.byKey(const ValueKey('location_header'));

      if (await waitFor(tester, locationHeaderFinder)) {
        await tester.tap(locationHeaderFinder, warnIfMissed: false);

        final dragHandle = find.byKey(const ValueKey('travel_warning_drag_handle'));

        if (await waitFor(tester, dragHandle)) {
          await tester.drag(dragHandle, const Offset(0, -3000));
          await pumpFor(tester, const Duration(seconds: 3));
          await _save(tester, lang, '04_country_info');
          await back(tester);
        }
      }

      final tabDataFinder = find.byKey(const ValueKey('tab_data'));

      if (await waitFor(tester, tabDataFinder)) {
        await tester.tap(tabDataFinder);
        await pumpFor(tester, const Duration(seconds: 1));

        final vaccinationsFinder = find.byKey(const ValueKey('data_vaccinations'));

        if (await waitFor(tester, vaccinationsFinder)) {
          await tester.tap(vaccinationsFinder);
          await pumpFor(tester, const Duration(seconds: 3));
          await _save(tester, lang, '05_vaccinations');
          await back(tester);
        }
      }

      final entryCheckData = await dataService.getCachedData();

      navigatorKey.currentState!.push(
        MaterialPageRoute(
          builder: (_) => EntryCheckPage(
            data: entryCheckData,
            trip: Trip(
              countryCode: 'TH',
              countryName: 'Thailand',
              start: tripStart,
              end: tripStart.add(const Duration(days: 14)),
            ),
          ),
        ),
      );
      await pumpFor(tester, const Duration(seconds: 5));
      await _save(tester, lang, '06_entry_check');
      await back(tester);

      final tabMemoriesFinder = find.byKey(const ValueKey('tab_memories'));

      if (await waitFor(tester, tabMemoriesFinder)) {
        await tester.tap(tabMemoriesFinder);
        await pumpFor(tester, const Duration(seconds: 8));
        await _save(tester, lang, '07_memories');

        await tester.tap(find.text('Japan').first);
        await pumpFor(tester, const Duration(seconds: 5));
        await _save(tester, lang, '08_trip');
        await back(tester);
      }

      binding.reportData = {'screenshots': _screenshots};

      final tabHomeFinder = find.byKey(const ValueKey('tab_home'));

      if (await waitFor(tester, tabHomeFinder)) {
        await tester.tap(tabHomeFinder);
        await pumpFor(tester, const Duration(seconds: 1));
      }
    }
  });
}

Future<void> _save(WidgetTester tester, String lang, String name) async {
  await pumpFor(tester, const Duration(milliseconds: 500));

  final image = await captureImage(tester.element(find.byType(MaterialApp)));
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);

  _screenshots['$lang/$name'] = base64Encode(bytes!.buffer.asUint8List());

  debugPrint('Captured: $lang/$name');
}
