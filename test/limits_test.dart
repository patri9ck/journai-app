// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Patrick Zwick

import 'package:flutter_test/flutter_test.dart';
import 'package:journai_app/model/limits.dart';

void main() {
  test('only plans with more than one profile show profiles', () {
    final pro = Limits.fromJson({'imageScans': 20, 'features': {}, 'tier': 'PRO', 'profiles': 1});
    final family = Limits.fromJson({'imageScans': 100, 'features': {}, 'tier': 'FAMILY', 'profiles': 5});
    final withoutProfiles = Limits.fromJson({'imageScans': 5, 'features': {}, 'tier': 'FREE'});

    expect(pro.hasProfiles, isFalse);
    expect(family.hasProfiles, isTrue);
    expect(family.profiles, 5);
    expect(withoutProfiles.profiles, 1);
  });

  test('paid features are only enabled when the server grants them', () {
    final pro = Limits.fromJson({'features': {'TRIP': 20, 'RECEIPT': 100, 'ENTRY_CHECK': 1, 'TRAVEL_WARNING_ALERTS': 1}});
    final free = Limits.fromJson({'features': {'TRIP': 0, 'RECEIPT': 0}});
    final unknown = Limits.fromJson({'features': {}});

    expect([pro.tripsEnabled, pro.receiptsEnabled, pro.travelWarningAlertsEnabled], everyElement(isTrue));
    expect([free.tripsEnabled, free.receiptsEnabled], everyElement(isFalse));
    expect([unknown.tripsEnabled, unknown.receiptsEnabled], everyElement(isFalse));
  });
}
