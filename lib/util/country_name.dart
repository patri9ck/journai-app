// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Patrick Zwick

import 'package:flutter/widgets.dart';

import '../model/trip.dart';
import 'country_data.dart';

String localizedCountryName(BuildContext context, String countryCode) =>
    countryName(countryCode, Localizations.localeOf(context).languageCode);

String tripCountryName(BuildContext context, Trip trip) => localizedCountryName(context, trip.countryCode);

String tripPlaceName(BuildContext context, Trip trip) {
  final countryName = tripCountryName(context, trip);

  return trip.city.isEmpty ? countryName : '${trip.city}, $countryName';
}
