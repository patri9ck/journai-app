// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Patrick Zwick

import 'package:country_picker/country_picker.dart';
import 'package:flutter/widgets.dart';

import '../model/trip.dart';

String localizedCountryName(BuildContext context, String countryCode, String fallback) =>
    CountryLocalizations.of(context)?.countryName(countryCode: countryCode.toUpperCase()) ?? fallback;

String tripCountryName(BuildContext context, Trip trip) => localizedCountryName(context, trip.countryCode, trip.countryName);

String tripPlaceName(BuildContext context, Trip trip) {
  final countryName = tripCountryName(context, trip);

  return trip.city.isEmpty ? countryName : '${trip.city}, $countryName';
}
