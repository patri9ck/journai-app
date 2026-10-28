// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Patrick Zwick

class DayWeather {
  final double temperature;
  final double precipitation;

  const DayWeather({required this.temperature, required this.precipitation});

  static DayWeather fromJson(Map<String, dynamic> json) => DayWeather(
    temperature: (json['temperature'] as num).toDouble(),
    precipitation: (json['precipitation'] as num).toDouble(),
  );

  bool get isRainy => precipitation >= 1;

  Map<String, dynamic> toJson() => {'temperature': temperature, 'precipitation': precipitation};
}
