// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Patrick Zwick

import 'dart:convert';
import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:journai_app/service/travel_warning_service.dart';
import 'package:journai_app/util/cache.dart';
import 'package:journai_app/util/storage.dart';

const travelWarningList = {
  'response': {
    'contentList': ['222', '111'],
    '222': {'iso3CountryCode': 'THA', 'countryName': 'Thailand', 'warning': true, 'partialWarning': false},
    '111': {'iso3CountryCode': 'DEU', 'countryName': 'Deutschland', 'warning': false, 'partialWarning': false},
  },
};

void main() {
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  TravelWarningService service() => TravelWarningService();

  test('a warning is found by ISO2 country code', () async {
    final result = await http.runWithClient(
      () => service().getWarningForCountry('TH'),
      () => MockClient((request) async {
        expect(request.url.host, 'www.auswaertiges-amt.de');

        return http.Response(jsonEncode(travelWarningList), 200);
      }),
    );

    expect(result.networkError, isFalse);
    expect(result.warning?.countryGermanName, 'Thailand');
    expect(result.warning?.hasWarning, isTrue);
    expect(result.warning?.countryId, 222);
  });

  test('unknown countries have no warning', () async {
    final result = await http.runWithClient(
      () => service().getWarningForCountry('XX'),
      () => MockClient((request) async => http.Response(jsonEncode(travelWarningList), 200)),
    );

    expect(result.warning, isNull);
    expect(result.networkError, isFalse);
  });

  test('a network error falls back to the cache and reports the error only without cache', () async {
    await saveListCache('cache_travel_warnings', [
      {
        'iso3CountryCode': 'THA',
        'countryName': 'Thailand',
        'warning': true,
        'partialWarning': false,
        '_id': '222',
      },
    ]);

    final cached = await http.runWithClient(
      () => service().getWarningForCountry('TH'),
      () => MockClient((request) async => throw const SocketException('offline')),
    );

    expect(cached.networkError, isFalse);
    expect(cached.warning?.countryGermanName, 'Thailand');

    await storage.delete(key: 'cache_travel_warnings');

    final uncached = await http.runWithClient(
      () => service().getWarningForCountry('TH'),
      () => MockClient((request) async => throw const SocketException('offline')),
    );

    expect(uncached.networkError, isTrue);
    expect(uncached.warning, isNull);
  });

  test('malformed JSON is treated like a failed request', () async {
    final result = await http.runWithClient(
      () => service().getWarningForCountry('TH'),
      () => MockClient((request) async => http.Response('not json', 200)),
    );

    expect(result.networkError, isTrue);
  });
}
