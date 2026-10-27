// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Patrick Zwick

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../messages/app_localizations.dart';
import '../util/storage.dart';

class TravelWarningAlertService {
  static const _countriesKey = 'travel_warning_alert_countries';
  static const _tripCountriesKey = 'travel_warning_alert_trip_countries';
  static const _subscribedKey = 'travel_warning_alert_subscribed';

  Future<void> _pendingSync = Future.value();

  Future<List<String>> getWatchedCountries() => _readList(_countriesKey);

  Future<bool> watch(String iso3CountryCode) async {
    try {
      final settings = await FirebaseMessaging.instance.requestPermission();

      if (settings.authorizationStatus != AuthorizationStatus.authorized) {
        return false;
      }
    } on PlatformException {
      return false;
    } on FirebaseException {
      return false;
    }

    final countries = await getWatchedCountries();

    if (!countries.contains(iso3CountryCode)) {
      await _writeList(_countriesKey, [...countries, iso3CountryCode]);
    }

    await sync(true);

    return true;
  }

  Future<void> unwatch(String iso3CountryCode) async {
    final countries = await getWatchedCountries();

    await _writeList(_countriesKey, countries.where((country) => country != iso3CountryCode).toList());
    await sync(true);
  }

  Future<void> setTripCountries(List<String> iso3CountryCodes) => _writeList(_tripCountriesKey, iso3CountryCodes);

  Future<void> sync(bool enabled) => _pendingSync = _pendingSync.then((_) => _sync(enabled));

  Future<void> _sync(bool enabled) async {
    final language = _currentLanguage();
    final countries = {...await getWatchedCountries(), ...await _readList(_tripCountriesKey)};
    final desired = enabled ? {for (final country in countries) _topic(country, language)} : <String>{};
    final subscribed = (await _readList(_subscribedKey)).toSet();

    try {
      for (final topic in subscribed.difference(desired)) {
        await FirebaseMessaging.instance.unsubscribeFromTopic(topic);
      }

      for (final topic in desired.difference(subscribed)) {
        await FirebaseMessaging.instance.subscribeToTopic(topic);
      }
    } on PlatformException {
      return;
    } on FirebaseException {
      return;
    }

    await _writeList(_subscribedKey, desired.toList());
  }

  Future<void> clear() async {
    await sync(false);
    await storage.delete(key: _countriesKey);
    await storage.delete(key: _tripCountriesKey);
  }

  String _topic(String iso3CountryCode, String language) => 'travel-warning-$iso3CountryCode-$language';

  String _currentLanguage() {
    final language = WidgetsBinding.instance.platformDispatcher.locale.languageCode;
    final supported = AppLocalizations.supportedLocales.any((locale) => locale.languageCode == language);

    return supported ? language : 'en';
  }

  Future<List<String>> _readList(String key) async {
    final raw = await storage.read(key: key);

    if (raw == null || raw.isEmpty) {
      return [];
    }

    return raw.split(',');
  }

  Future<void> _writeList(String key, List<String> values) => storage.write(key: key, value: values.join(','));
}
