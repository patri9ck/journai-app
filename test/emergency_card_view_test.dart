// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Patrick Zwick

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:journai_app/messages/app_localizations.dart';
import 'package:journai_app/model/data.dart';
import 'package:journai_app/widget/shared/emergency_card_view.dart';

void main() {
  final localizations = lookupAppLocalizations(const Locale('en'));

  Widget card({List<String> allergies = const [], List<Data> vaccines = const []}) => MaterialApp(
    home: SingleChildScrollView(
      child: EmergencyCardView(
        localizations: localizations,
        allergies: allergies,
        conditions: const [],
        vitalSigns: const [],
        healthValues: const [],
        vaccines: vaccines,
      ),
    ),
  );

  testWidgets('the card shows the stored health data', (tester) async {
    await tester.pumpWidget(
      card(allergies: ['Penicillin'], vaccines: [Data(feature: 'VACCINE', fields: {'name': 'Havrix', 'disease': 'Hepatitis A'})]),
    );

    expect(find.text(localizations.dashboardEmergencyCardTitle), findsOneWidget);
    expect(find.text('Penicillin'), findsOneWidget);
    expect(find.text('Havrix - Hepatitis A'), findsOneWidget);
  });

  testWidgets('an empty card says that nothing is stored', (tester) async {
    await tester.pumpWidget(card());

    expect(find.text(localizations.dashboardEmergencyNoAllergies), findsOneWidget);
    expect(find.text(localizations.dashboardEmergencyNoVaccines), findsOneWidget);
  });
}
