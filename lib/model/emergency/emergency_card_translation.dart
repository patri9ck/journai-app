// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Patrick Zwick

import '../data.dart';
import '../limits.dart';

class EmergencyCardTranslation {
  final String languageCode;
  final List<String> allergies;
  final List<String> conditions;
  final List<String> vitalSigns;
  final List<String> healthValues;
  final List<String> vaccineNames;
  final List<String?> vaccineDiseases;
  final String dataHash;

  const EmergencyCardTranslation({
    required this.languageCode,
    required this.allergies,
    required this.conditions,
    required this.vitalSigns,
    required this.healthValues,
    required this.vaccineNames,
    required this.vaccineDiseases,
    required this.dataHash,
  });

  factory EmergencyCardTranslation.fromJson(Map<String, dynamic> json) =>
      EmergencyCardTranslation(
        languageCode: json['languageCode'] as String,
        allergies: (json['allergies'] as List).cast<String>(),
        conditions: (json['conditions'] as List).cast<String>(),
        vitalSigns: (json['vitalSigns'] as List?)?.cast<String>() ?? [],
        healthValues: (json['healthValues'] as List).cast<String>(),
        vaccineNames: (json['vaccineNames'] as List).cast<String>(),
        vaccineDiseases: (json['vaccineDiseases'] as List).cast<String?>(),
        dataHash: json['dataHash'] as String,
      );

  Map<String, dynamic> toJson() => {
    'languageCode': languageCode,
    'allergies': allergies,
    'conditions': conditions,
    'vitalSigns': vitalSigns,
    'healthValues': healthValues,
    'vaccineNames': vaccineNames,
    'vaccineDiseases': vaccineDiseases,
    'dataHash': dataHash,
  };

  static String hashFrom(List<Data> healthData) {
    final sorted = List.of(healthData)
      ..sort((first, second) => (first.id ?? 0).compareTo(second.id ?? 0));
    final text = sorted.map((data) => '${data.feature}:${data.id}:${data.fields}').join('|');
    var hash = 0;

    for (final rune in text.runes) {
      hash = (hash * 31 + rune) & 0x7FFFFFFF;
    }

    return hash.toString();
  }

  static List<String> allergiesFrom(List<Data> healthData) => healthData
      .where((data) => data.feature == 'ALLERGY')
      .map((data) => data.fields['name'] as String? ?? '')
      .where((name) => name.isNotEmpty)
      .toList();

  static List<String> conditionsFrom(List<Data> healthData) => healthData
      .where((data) => data.feature == 'CONDITION')
      .map((data) => data.fields['name'] as String? ?? '')
      .where((name) => name.isNotEmpty)
      .toList();

  static const _vitalFeatures = [
    'HEIGHT', 'WEIGHT', 'BLOOD_TYPE', 'RH_FACTOR', 'ORGAN_DONOR', 'AGE',
  ];

  static String _formatVitalValue(Data item, bool metricUnits) {
    final rawValue = item.fields['value'] as String? ?? '';
    final numericValue = double.tryParse(rawValue);

    if (numericValue == null) {
      return rawValue;
    }

    if (item.feature == 'HEIGHT') {
      return metricUnits
          ? '$rawValue cm'
          : '${(numericValue / 2.54).toStringAsFixed(1)} in';
    }

    if (item.feature == 'WEIGHT') {
      return metricUnits
          ? '$rawValue kg'
          : '${(numericValue * 2.20462).toStringAsFixed(1)} lbs';
    }

    return rawValue;
  }

  static List<String> vitalSignsFrom(List<Data> healthData, {bool metricUnits = true}) {
    return _vitalFeatures
        .map((feature) => healthData.where((data) => data.feature == feature).firstOrNull)
        .where((item) => item != null && (item.fields['value'] as String? ?? '').isNotEmpty)
        .map((item) => '${item!.fields['key'] ?? ''}: ${_formatVitalValue(item, metricUnits)}')
        .where((line) => line.trim() != ':')
        .toList();
  }

  static List<String> healthValuesFrom(List<Data> healthData) => healthData
      .where((data) => Limits.healthValueFeatures.contains(data.feature))
      .where((data) => !_vitalFeatures.contains(data.feature))
      .where((data) => (data.fields['value'] as String? ?? '').isNotEmpty)
      .map((data) => '${data.fields['key'] ?? ''}: ${data.fields['value'] ?? ''}')
      .where((line) => line.trim() != ':')
      .toList();

  static List<String> vaccineNamesFrom(List<Data> healthData) => healthData
      .where((data) => data.feature == 'VACCINE')
      .map((data) => data.fields['name'] as String? ?? '-')
      .toList();

  static List<String?> vaccineDiseaseFrom(List<Data> healthData) => healthData
      .where((data) => data.feature == 'VACCINE')
      .map((data) => data.fields['disease'] as String?)
      .toList();
}
