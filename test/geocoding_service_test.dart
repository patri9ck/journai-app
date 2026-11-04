// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Patrick Zwick

import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:journai_app/service/geocoding_service.dart';

const photonResponse = {
  'features': [
    {
      'geometry': {'coordinates': [13.4, 52.5]},
      'properties': {'name': 'Berlin', 'type': 'city', 'countrycode': 'de', 'country': 'Germany', 'state': 'Berlin'},
    },
    {
      'geometry': {'coordinates': [11.5, 48.1]},
      'properties': {'name': 'Munich', 'type': 'city', 'countrycode': 'de', 'country': 'Germany', 'state': 'Bavaria'},
    },
    {
      'geometry': {'coordinates': [8.6, 47.4]},
      'properties': {'name': 'Zurich', 'type': 'city', 'countrycode': 'ch', 'country': 'Switzerland'},
    },
    {
      'geometry': {'coordinates': [16.4, 48.2]},
      'properties': {'name': 'Vienna', 'type': 'city', 'country': 'Austria'},
    },
    {
      'geometry': {'coordinates': [2.3, 48.8]},
      'properties': {'name': 'Paris', 'type': 'city', 'countrycode': 'fr'},
    },
    {
      'geometry': {'coordinates': [18.1, 59.3]},
      'properties': {'name': 'Stockholm Hamlet', 'type': 'hamlet', 'countrycode': 'se'},
    },
  ],
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  test('searchPlaces filters by country and ranks best matches first', () async {
    final service = GeocodingService(contactEmail: 'test@journai.xyz');

    final suggestions = await http.runWithClient(
      () => service.searchPlaces('ber', 'DE'),
      () => MockClient((request) async {
        expect(request.url.host, 'photon.komoot.io');

        return http.Response(jsonEncode(photonResponse), 200);
      }),
    );

    expect(suggestions.map((suggestion) => suggestion.name), ['Berlin', 'Munich']);
    expect(suggestions.first.detail, 'Berlin, Germany');
  });

  test('results without a country code are not returned when filtering by country', () async {
    final service = GeocodingService(contactEmail: 'test@journai.xyz');

    final suggestions = await http.runWithClient(
      () => service.searchPlaces('vie', 'AT'),
      () => MockClient((request) async => http.Response(jsonEncode(photonResponse), 200)),
    );

    expect(suggestions.map((suggestion) => suggestion.name), isEmpty);
  });

  test('short queries and non-200 responses return nothing', () async {
    final service = GeocodingService(contactEmail: 'test@journai.xyz');

    expect(await service.searchPlaces('b', 'DE'), isEmpty);

    final suggestions = await http.runWithClient(
      () => service.searchPlaces('ber', 'DE'),
      () => MockClient((request) async => http.Response('rate limited', 429)),
    );

    expect(suggestions, isEmpty);
  });

  test('getCityCenter returns the first result with coordinates', () async {
    final service = GeocodingService(contactEmail: 'test@journai.xyz');

    final center = await http.runWithClient(
      () => service.getCityCenter('Berlin', 'de'),
      () => MockClient((request) async => http.Response(jsonEncode(photonResponse), 200)),
    );

    expect(center?.latitude, 52.5);
    expect(center?.longitude, 13.4);
  });

  test('reverseGeocode maps the nominatim address fields', () async {
    final service = GeocodingService(contactEmail: 'test@journai.xyz');

    final info = await http.runWithClient(
      () => service.reverseGeocode(52.5, 13.4),
      () => MockClient((request) async {
        expect(request.url.host, 'nominatim.openstreetmap.org');

        return http.Response(
          jsonEncode({
            'address': {'city': 'Berlin', 'country': 'Germany', 'country_code': 'de'},
          }),
          200,
        );
      }),
    );

    expect(info?.city, 'Berlin');
    expect(info?.countryName, 'Germany');
    expect(info?.countryCode, 'DE');
  });

  test('reverseGeocode falls back to town, village and county', () async {
    final service = GeocodingService(contactEmail: 'test@journai.xyz');

    final info = await http.runWithClient(
      () => service.reverseGeocode(48.1, 11.5),
      () => MockClient((request) async => http.Response(
            jsonEncode({
              'address': {'town': 'Garching', 'county': 'Munich', 'country': 'Germany', 'country_code': 'de'},
            }),
            200,
          )),
    );

    expect(info?.city, 'Garching');
  });
}
