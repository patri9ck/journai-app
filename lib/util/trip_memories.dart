// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Patrick Zwick

import '../model/data.dart';
import '../model/day_weather.dart';
import '../model/result.dart';
import '../model/trip.dart';
import '../service/services.dart';
import '../widget/shared/trip_stripes.dart';
import 'document_date.dart';
import 'temperature_color.dart';

Future<Map<DateTime, DayWeather>> loadTripWeather(Trip trip) async {
  final center = await geocodingService.getCountryCenter(trip.countryCode);

  if (center == null) {
    return {};
  }

  return weatherService.getDailyWeather(center, trip.start, trip.end);
}

double? averageTemperature(Map<DateTime, DayWeather> weather) {
  if (weather.isEmpty) {
    return null;
  }

  return weather.values.fold(0.0, (sum, day) => sum + day.temperature) / weather.length;
}

List<TripStripe> tripStripes(Trip trip, Map<DateTime, DayWeather> weather, {Set<DateTime> memoryDays = const {}}) => [
  for (final day in trip.days)
    TripStripe(
      color: temperatureColor(weather[day]?.temperature),
      rainy: weather[day]?.isRainy ?? false,
      hasMemory: memoryDays.contains(day),
    ),
];

List<Data> tripAlbum(Trip trip, List<Data> data) => data
    .where((entry) => entry.feature == 'TICKET' || entry.feature == 'RECEIPT')
    .where((entry) {
      final date = parseDocumentDate(entry.fields['date'] as String?);

      return date != null && trip.contains(date);
    })
    .toList();

Future<Result<void>> deleteTripWithMemories(Trip trip, List<Data> data) async {
  final memories = data.where(
    (entry) => (entry.feature == 'JOURNAL_ENTRY' || entry.feature == 'TIME_CAPSULE') && entry.fields['tripId'] == trip.id,
  );

  for (final memory in memories) {
    final result = await dataService.deleteData(memory.id!);

    if (result is Failure<void>) {
      return result;
    }
  }

  return dataService.deleteData(trip.id!);
}
