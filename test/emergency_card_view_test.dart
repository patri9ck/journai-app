// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Patrick Zwick

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:journai_app/messages/app_localizations.dart';
import 'package:journai_app/model/data.dart';
import 'package:journai_app/model/emergency/emergency_card_content.dart';
import 'package:journai_app/model/emergency/emergency_card_translation.dart';
import 'package:journai_app/widget/shared/emergency_card_view.dart';

void main() {
  final localizations = lookupAppLocalizations(const Locale('en'));

  Widget card(List<Data> healthData) => MaterialApp(
    home: SingleChildScrollView(
      child: EmergencyCardView(
        localizations: localizations,
        content: EmergencyCardContent.fromHealthData(healthData, metricUnits: true),
      ),
    ),
  );

  testWidgets('the card shows the stored health data', (tester) async {
    await tester.pumpWidget(
      card([
        Data(feature: 'ALLERGY', fields: {'name': 'Penicillin'}),
        Data(feature: 'VACCINE', fields: {'name': 'Havrix', 'disease': 'Hepatitis A', 'date': '2024-03-01'}),
      ]),
    );

    expect(find.text(localizations.dashboardEmergencyCardTitle), findsOneWidget);
    expect(find.text('Penicillin'), findsOneWidget);
    expect(find.text('Havrix - Hepatitis A - 2024-03-01'), findsOneWidget);
  });

  testWidgets('an empty card says that nothing is stored', (tester) async {
    await tester.pumpWidget(card(const []));

    expect(find.text(localizations.dashboardEmergencyNoAllergies), findsOneWidget);
    expect(find.text(localizations.dashboardEmergencyNoVaccines), findsOneWidget);
  });

  test('a translated card keeps the vaccination dates of the original data', () {
    final healthData = [
      Data(feature: 'VACCINE', fields: {'name': 'Havrix', 'disease': 'Hepatitis A', 'date': '2024-03-01'}),
    ];

    final translation = EmergencyCardTranslation(
      languageCode: 'de',
      allergies: const [],
      conditions: const [],
      vitalSigns: const [],
      healthValues: const [],
      vaccineNames: const ['Havrix'],
      vaccineDiseases: const ['Hepatitis A (de)'],
      dataHash: '',
    );

    expect(EmergencyCardContent.fromTranslation(translation, healthData).vaccines, [
      'Havrix - Hepatitis A (de) - 2024-03-01',
    ]);
  });
}
