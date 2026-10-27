// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Patrick Zwick

import 'package:flutter/material.dart';

const unknownTemperatureColor = Color(0xFFB8BCC6);

const _temperatureStops = [
  (-15.0, Color(0xFF1E3F8A)),
  (0.0, Color(0xFF3F7FD9)),
  (10.0, Color(0xFF9CC3EC)),
  (17.0, Color(0xFFEDDDB4)),
  (24.0, Color(0xFFF2A65A)),
  (32.0, Color(0xFFD2552A)),
  (40.0, Color(0xFF9E2A1B)),
];

Color temperatureColor(double? temperature) {
  if (temperature == null) {
    return unknownTemperatureColor;
  }

  if (temperature <= _temperatureStops.first.$1) {
    return _temperatureStops.first.$2;
  }

  for (var index = 1; index < _temperatureStops.length; index++) {
    final (upperTemperature, upperColor) = _temperatureStops[index];

    if (temperature <= upperTemperature) {
      final (lowerTemperature, lowerColor) = _temperatureStops[index - 1];

      return Color.lerp(lowerColor, upperColor, (temperature - lowerTemperature) / (upperTemperature - lowerTemperature))!;
    }
  }

  return _temperatureStops.last.$2;
}

Color stampInkColor(double? temperature) =>
    Color.lerp(temperatureColor(temperature), const Color(0xFF1A1C22), 0.5)!;
