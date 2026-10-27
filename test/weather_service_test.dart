// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Patrick Zwick

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:journai_app/service/weather_service.dart';
import 'package:latlong2/latlong.dart';

void main() {
  test('past trips read their daily weather from the archive', () async {
    final requestedHosts = <String>[];

    final weather = await http.runWithClient(
      () => WeatherService().getDailyWeather(const LatLng(35, 135.7), DateTime(2026, 4, 4), DateTime(2026, 4, 5)),
      () => MockClient((request) async {
        requestedHosts.add(request.url.host);

        return http.Response(
          jsonEncode({
            'daily': {
              'time': ['2026-04-04', '2026-04-05'],
              'temperature_2m_mean': [14.2, null],
              'precipitation_sum': [3.1, 0],
            },
          }),
          200,
        );
      }),
    );

    expect(requestedHosts, ['archive-api.open-meteo.com']);
    expect(weather.keys, [DateTime(2026, 4, 4)]);
    expect(weather[DateTime(2026, 4, 4)]!.isRainy, isTrue);
  });

  test('a failed request returns no weather', () async {
    final weather = await http.runWithClient(
      () => WeatherService().getDailyWeather(const LatLng(35, 135.7), DateTime(2026, 4, 4), DateTime(2026, 4, 5)),
      () => MockClient((_) async => http.Response('error', 500)),
    );

    expect(weather, isEmpty);
  });
}
