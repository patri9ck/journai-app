// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Patrick Zwick

class DayWeather {
  final double temperature;
  final double precipitation;

  const DayWeather({required this.temperature, required this.precipitation});

  bool get isRainy => precipitation >= 1;
}
