// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Patrick Zwick

import '../messages/app_localizations.dart';

String formatTemperature(AppLocalizations localizations, double celsius, {required bool metricUnits}) {
  if (metricUnits) {
    return localizations.temperatureCelsius(celsius.round());
  }

  return localizations.temperatureFahrenheit((celsius * 9 / 5 + 32).round());
}
