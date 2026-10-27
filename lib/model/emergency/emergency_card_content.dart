// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Patrick Zwick

import '../data.dart';
import 'emergency_card_translation.dart';

class EmergencyCardContent {
  final List<String> allergies;
  final List<String> conditions;
  final List<String> vitalSigns;
  final List<String> healthValues;
  final List<String> vaccines;

  const EmergencyCardContent({
    this.allergies = const [],
    this.conditions = const [],
    this.vitalSigns = const [],
    this.healthValues = const [],
    this.vaccines = const [],
  });

  factory EmergencyCardContent.fromHealthData(List<Data> healthData, {required bool metricUnits}) {
    final vaccines = _vaccines(healthData);

    return EmergencyCardContent(
      allergies: EmergencyCardTranslation.allergiesFrom(healthData),
      conditions: EmergencyCardTranslation.conditionsFrom(healthData),
      vitalSigns: EmergencyCardTranslation.vitalSignsFrom(healthData, metricUnits: metricUnits),
      healthValues: EmergencyCardTranslation.healthValuesFrom(healthData),
      vaccines: [
        for (final vaccine in vaccines)
          vaccineLabel(
            vaccine.fields['name'] as String? ?? '-',
            vaccine.fields['disease'] as String?,
            vaccine.fields['date'] as String?,
          ),
      ],
    );
  }

  factory EmergencyCardContent.fromTranslation(EmergencyCardTranslation translation, List<Data> healthData) {
    final vaccines = _vaccines(healthData);

    return EmergencyCardContent(
      allergies: translation.allergies,
      conditions: translation.conditions,
      vitalSigns: translation.vitalSigns,
      healthValues: translation.healthValues,
      vaccines: [
        for (final (index, name) in translation.vaccineNames.indexed)
          vaccineLabel(
            name,
            index < translation.vaccineDiseases.length ? translation.vaccineDiseases[index] : null,
            index < vaccines.length ? vaccines[index].fields['date'] as String? : null,
          ),
      ],
    );
  }

  static List<Data> _vaccines(List<Data> healthData) => healthData.where((data) => data.feature == 'VACCINE').toList();
}

String vaccineLabel(String name, String? disease, String? date) {
  final details = [if (disease != null && disease.isNotEmpty) disease, if (date != null && date.isNotEmpty) date];

  return details.isEmpty ? name : '$name - ${details.join(' - ')}';
}
