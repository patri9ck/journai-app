// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Patrick Zwick

import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:journai_app/service/overpass_service.dart';

void main() {
  final overpassService = OverpassService(contactEmail: 'test@journai.xyz');
  final body = jsonEncode({
    'elements': [
      {
        'lat': 48.8566,
        'lon': 2.3522,
        'tags': {'amenity': 'pharmacy', 'name': 'Pharmacie'},
      },
    ],
  });

  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  test('an overloaded server is retried', () async {
    var requests = 0;

    final pois = await http.runWithClient(
      () => overpassService.getNearbyPois(48.8566, 2.3522),
      () => MockClient((_) async {
        requests++;

        return requests == 1 ? http.Response('busy', 504) : http.Response(body, 200);
      }),
    );

    expect(requests, 2);
    expect(pois?.single.name, 'Pharmacie');
  });

  test('a failure without a response returns null instead of an empty list', () async {
    final pois = await http.runWithClient(
      () => overpassService.getNearbyPois(48.8566, 2.3522),
      () => MockClient((_) async => throw http.ClientException('offline')),
    );

    expect(pois, isNull);
  });

  test('cached places are only used near where they were loaded', () async {
    await http.runWithClient(
      () => overpassService.getNearbyPois(48.8566, 2.3522),
      () => MockClient((_) async => http.Response(body, 200)),
    );

    expect(await overpassService.getCachedPois(48.86, 2.35), hasLength(1));
    expect(await overpassService.getCachedPois(52.52, 13.405), isEmpty);
  });
}
