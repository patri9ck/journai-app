// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Patrick Zwick

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../model/day_weather.dart';

class WeatherService {
  static const _archiveDelay = Duration(days: 6);
  static const _forecastRange = Duration(days: 15);

  final _dailyWeather = <String, Map<DateTime, DayWeather>>{};

  Future<double?> getCurrentTemperature(double latitude, double longitude) async {
    try {
      final response = await http
          .get(
            Uri.parse(
              'https://api.open-meteo.com/v1/forecast'
              '?latitude=$latitude&longitude=$longitude'
              '&current=temperature_2m',
            ),
          )
          .timeout(const Duration(seconds: 5));

      if (response.statusCode != 200) {
        return null;
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;

      return (json['current']?['temperature_2m'] as num?)?.toDouble();
    } on IOException {
      return null;
    } on http.ClientException {
      return null;
    } on TimeoutException {
      return null;
    } on FormatException {
      return null;
    }
  }

  Future<Map<DateTime, DayWeather>> getDailyWeather(LatLng position, DateTime start, DateTime end) async {
    final cacheKey = '${position.latitude},${position.longitude},$start,$end';
    final cached = _dailyWeather[cacheKey];

    if (cached != null) {
      return cached;
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final archiveEnd = today.subtract(_archiveDelay);
    final forecastStart = start.isAfter(archiveEnd) ? start : archiveEnd.add(const Duration(days: 1));
    final forecastEnd = today.add(_forecastRange);
    final weather = <DateTime, DayWeather>{};

    if (!start.isAfter(archiveEnd)) {
      weather.addAll(
        await _getDailyWeather(
          'https://archive-api.open-meteo.com/v1/archive',
          position,
          start,
          end.isAfter(archiveEnd) ? archiveEnd : end,
        ),
      );
    }

    if (!forecastStart.isAfter(end) && !forecastStart.isAfter(forecastEnd)) {
      weather.addAll(
        await _getDailyWeather(
          'https://api.open-meteo.com/v1/forecast',
          position,
          forecastStart,
          end.isAfter(forecastEnd) ? forecastEnd : end,
        ),
      );
    }

    if (weather.isNotEmpty) {
      _dailyWeather[cacheKey] = weather;
    }

    return weather;
  }

  Future<Map<DateTime, DayWeather>> _getDailyWeather(String url, LatLng position, DateTime start, DateTime end) async {
    try {
      final response = await http
          .get(
            Uri.parse(
              '$url?latitude=${position.latitude}&longitude=${position.longitude}'
              '&start_date=${_formatDate(start)}&end_date=${_formatDate(end)}'
              '&daily=temperature_2m_mean,precipitation_sum&timezone=auto',
            ),
          )
          .timeout(const Duration(seconds: 8));

      if (response.statusCode != 200) {
        return {};
      }

      final daily = (jsonDecode(response.body) as Map<String, dynamic>)['daily'] as Map<String, dynamic>?;
      final dates = (daily?['time'] as List?) ?? [];
      final temperatures = (daily?['temperature_2m_mean'] as List?) ?? [];
      final precipitations = (daily?['precipitation_sum'] as List?) ?? [];
      final weather = <DateTime, DayWeather>{};

      for (var index = 0; index < dates.length && index < temperatures.length; index++) {
        final temperature = (temperatures[index] as num?)?.toDouble();

        if (temperature == null) {
          continue;
        }

        weather[DateTime.parse(dates[index] as String)] = DayWeather(
          temperature: temperature,
          precipitation: index < precipitations.length ? (precipitations[index] as num?)?.toDouble() ?? 0 : 0,
        );
      }

      return weather;
    } on IOException {
      return {};
    } on http.ClientException {
      return {};
    } on TimeoutException {
      return {};
    } on FormatException {
      return {};
    }
  }

  String _formatDate(DateTime date) => date.toIso8601String().substring(0, 10);
}
