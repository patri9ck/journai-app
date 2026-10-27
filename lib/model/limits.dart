// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Patrick Zwick

class Limits {
  final int imageScans;
  final Map<String, int> features;
  final String tier;
  final int profiles;

  const Limits({required this.imageScans, required this.features, this.tier = 'FREE', this.profiles = 1});

  static const unlimited = Limits(imageScans: -1, features: {}, tier: 'FREE');

  bool get isFree => tier == 'FREE';
  bool get isPro => tier == 'PRO';
  bool get isFamily => tier == 'FAMILY';
  bool get hasProfiles => profiles > 1;

  factory Limits.fromJson(Map<String, dynamic> json) => Limits(
    imageScans: json['imageScans'] as int? ?? -1,
    tier: json['tier'] as String? ?? 'FREE',
    profiles: json['profiles'] as int? ?? 1,
    features: Map<String, int>.from(
      ((json['features'] as Map?)?.map(
            (key, value) => MapEntry(key as String, value as int),
          )) ??
          {},
    ),
  );

  static const healthValueFeatures = [
    'BLOOD_TYPE', 'RH_FACTOR', 'HEIGHT', 'WEIGHT', 'BMI',
    'EYE_COLOR', 'HAIR_COLOR', 'ORGAN_DONOR', 'AGE', 'MISCELLANEOUS',
  ];

  bool isFeatureEnabled(String key) {
    final limit = features[key];
    return limit == null || limit != 0;
  }

  bool get vaccinesEnabled => isFeatureEnabled('VACCINE');

  bool get isAnyHealthValueEnabled =>
      healthValueFeatures.any((feature) => isFeatureEnabled(feature));

  bool get countryInfoSafetyEnabled => isFeatureEnabled('COUNTRY_INFO_SAFETY');
  bool get countryInfoTravelEnabled => isFeatureEnabled('COUNTRY_INFO_TRAVEL');
  bool get countryInfoEntryEnabled => isFeatureEnabled('COUNTRY_INFO_ENTRY');
  bool get countryInfoHealthEnabled => isFeatureEnabled('COUNTRY_INFO_HEALTH');
  bool get countryInfoLegalEnabled => isFeatureEnabled('COUNTRY_INFO_LEGAL');
  bool get countryInfoLgbtqEnabled => isFeatureEnabled('COUNTRY_INFO_LGBTQ');
  bool get tripsEnabled => features['TRIP'] != null && features['TRIP'] != 0;
  bool get receiptsEnabled => features['RECEIPT'] != null && features['RECEIPT'] != 0;
  bool get travelWarningAlertsEnabled =>
      features['TRAVEL_WARNING_ALERTS'] != null && features['TRAVEL_WARNING_ALERTS'] != 0;
}
