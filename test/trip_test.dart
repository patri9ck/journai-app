// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Patrick Zwick

import 'package:flutter_test/flutter_test.dart';
import 'package:journai_app/model/data.dart';
import 'package:journai_app/model/trip.dart';

void main() {
  test('trips are read from data, sorted and invalid entries skipped', () {
    final trips = Trip.fromDataList([
      Data(feature: 'TRIP', fields: {'countryCode': 'JP', 'countryName': 'Japan', 'start': '2027-04-01', 'end': '2027-04-14'}),
      Data(feature: 'TRIP', fields: {'countryCode': 'TH', 'countryName': 'Thailand', 'start': '2027-01-10', 'end': '2027-01-24'}),
      Data(feature: 'TRIP', fields: {'countryCode': 'VN'}),
      Data(feature: 'VACCINE', fields: {'name': 'Havrix'}),
    ]);

    expect(trips.map((trip) => trip.countryCode), ['TH', 'JP']);
    expect(trips.first.isOver(DateTime(2027, 1, 25)), isTrue);
    expect(trips.first.isOver(DateTime(2027, 1, 24)), isFalse);
    expect(trips.first.toFields()['start'], '2027-01-10');
  });

  test('a trip lists every day it covers', () {
    final trip = Trip(countryCode: 'JP', countryName: 'Japan', start: DateTime(2027, 3, 30), end: DateTime(2027, 4, 2));

    expect(trip.days, [DateTime(2027, 3, 30), DateTime(2027, 3, 31), DateTime(2027, 4, 1), DateTime(2027, 4, 2)]);
    expect(trip.contains(DateTime(2027, 4, 2)), isTrue);
    expect(trip.contains(DateTime(2027, 4, 3)), isFalse);
  });
}
