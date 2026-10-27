// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Patrick Zwick

import 'package:flutter_test/flutter_test.dart';
import 'package:journai_app/model/data.dart';
import 'package:journai_app/model/day_weather.dart';
import 'package:journai_app/model/journal_entry.dart';
import 'package:journai_app/model/time_capsule.dart';
import 'package:journai_app/model/trip.dart';
import 'package:journai_app/util/temperature_color.dart';
import 'package:journai_app/util/trip_memories.dart';

void main() {
  final trip = Trip(id: 7, countryCode: 'JP', countryName: 'Japan', start: DateTime(2026, 4, 4), end: DateTime(2026, 4, 6));

  test('journal entries and time capsules survive a round trip through data and belong to their trip', () {
    final entry = JournalEntry(tripId: 7, date: DateTime(2026, 4, 5), text: 'Rain in Kyoto', sound: 'c291bmQ=');
    final timeCapsule = TimeCapsule(tripId: 7, text: 'Dear me', writtenAt: DateTime(2026, 4, 5), opensAt: DateTime(2027, 4, 5));
    final data = [
      Data(id: 1, feature: 'JOURNAL_ENTRY', fields: entry.toFields()),
      Data(id: 2, feature: 'JOURNAL_ENTRY', fields: {...entry.toFields(), 'tripId': 8}),
      Data(id: 3, feature: 'TIME_CAPSULE', fields: timeCapsule.toFields()),
    ];

    final entries = JournalEntry.fromDataList(data, 7);
    final timeCapsules = TimeCapsule.fromDataList(data);

    expect(entries.single.text, 'Rain in Kyoto');
    expect(entries.single.sound, 'c291bmQ=');
    expect(timeCapsules.single.isOpen(DateTime(2027, 4, 4)), isFalse);
    expect(timeCapsules.single.isOpen(DateTime(2027, 4, 5)), isTrue);
  });

  test('stripes follow the weather of each day and mark days with memories', () {
    final weather = {
      DateTime(2026, 4, 4): const DayWeather(temperature: -5, precipitation: 0),
      DateTime(2026, 4, 5): const DayWeather(temperature: 30, precipitation: 4),
    };

    final stripes = tripStripes(trip, weather, memoryDays: {DateTime(2026, 4, 5)});

    expect(stripes.length, 3);
    expect(stripes[0].color, temperatureColor(-5));
    expect(stripes[1].rainy, isTrue);
    expect(stripes[1].hasMemory, isTrue);
    expect(stripes[2].color, unknownTemperatureColor);
    expect(averageTemperature(weather), 12.5);
    expect(averageTemperature({}), isNull);
  });

  test('the scrapbook collects tickets and receipts from the trip dates', () {
    final album = tripAlbum(trip, [
      Data(feature: 'TICKET', fields: {'title': 'Shinkansen', 'date': '2026-04-05'}),
      Data(feature: 'RECEIPT', fields: {'merchant': 'Ichiran', 'date': '05.04.2026'}),
      Data(feature: 'TICKET', fields: {'title': 'Flight home', 'date': '2026-04-12'}),
      Data(feature: 'VACCINE', fields: {'date': '2026-04-05'}),
    ]);

    expect(album.map((item) => item.fields['title'] ?? item.fields['merchant']), ['Shinkansen', 'Ichiran']);
  });

  test('colder days are bluer and warmer days are redder', () {
    final cold = temperatureColor(-10);
    final warm = temperatureColor(30);

    expect(cold.b > cold.r, isTrue);
    expect(warm.r > warm.b, isTrue);
  });
}
