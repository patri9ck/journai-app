// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Patrick Zwick

import 'package:flutter/widgets.dart';

import '../messages/app_localizations.dart';

String deviceLanguageCode() {
  final language = WidgetsBinding.instance.platformDispatcher.locale.languageCode;
  final supported = AppLocalizations.supportedLocales.any((locale) => locale.languageCode == language);

  return supported ? language : 'en';
}

AppLocalizations deviceLocalizations() => lookupAppLocalizations(Locale(deviceLanguageCode()));
