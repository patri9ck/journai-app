// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Patrick Zwick

class CountryContent {
  final String? safety;
  final String? travel;
  final String? entry;
  final String? health;
  final String? legal;
  final String? lgbtq;

  const CountryContent({
    this.safety,
    this.travel,
    this.entry,
    this.health,
    this.legal,
    this.lgbtq,
  });

  factory CountryContent.fromJson(Map<String, dynamic> json) => CountryContent(
    safety: json['safety'] as String?,
    travel: json['travel'] as String?,
    entry: json['entry'] as String?,
    health: json['health'] as String?,
    legal: json['legal'] as String?,
    lgbtq: json['lgbtq'] as String?,
  );

  Map<String, dynamic> toJson() => {
    'safety': safety,
    'travel': travel,
    'entry': entry,
    'health': health,
    'legal': legal,
    'lgbtq': lgbtq,
  };
}
