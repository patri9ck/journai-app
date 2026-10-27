// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Patrick Zwick

import 'dart:convert';

import 'package:http/http.dart' as http;

import '../util/storage.dart';

class CurrencyService {
  static const _cacheKey = 'currency_rates_cache';

  static const Map<String, String> countryToCurrency = {
    'AD': 'EUR', 'AT': 'EUR', 'AX': 'EUR', 'BE': 'EUR', 'BL': 'EUR',
    'CY': 'EUR', 'DE': 'EUR', 'EE': 'EUR', 'ES': 'EUR', 'FI': 'EUR',
    'FR': 'EUR', 'GF': 'EUR', 'GP': 'EUR', 'GR': 'EUR', 'HR': 'EUR',
    'IE': 'EUR', 'IT': 'EUR', 'LT': 'EUR', 'LU': 'EUR', 'LV': 'EUR',
    'MC': 'EUR', 'ME': 'EUR', 'MF': 'EUR', 'MQ': 'EUR', 'MT': 'EUR',
    'NC': 'EUR', 'NL': 'EUR', 'PM': 'EUR', 'PT': 'EUR', 'RE': 'EUR',
    'SI': 'EUR', 'SK': 'EUR', 'SM': 'EUR', 'TF': 'EUR', 'VA': 'EUR',
    'XK': 'EUR', 'YT': 'EUR',
    'US': 'USD', 'EC': 'USD', 'SV': 'USD', 'PA': 'USD',
    'GB': 'GBP',
    'JP': 'JPY',
    'CN': 'CNY',
    'AU': 'AUD',
    'CA': 'CAD',
    'CH': 'CHF', 'LI': 'CHF',
    'SE': 'SEK',
    'NO': 'NOK',
    'DK': 'DKK', 'FO': 'DKK',
    'PL': 'PLN',
    'CZ': 'CZK',
    'HU': 'HUF',
    'RO': 'RON',
    'BG': 'BGN',
    'TR': 'TRY',
    'HK': 'HKD',
    'SG': 'SGD',
    'NZ': 'NZD',
    'IN': 'INR',
    'KR': 'KRW',
    'BR': 'BRL',
    'MX': 'MXN',
    'ZA': 'ZAR',
    'TH': 'THB',
    'ID': 'IDR',
    'MY': 'MYR',
    'PH': 'PHP',
    'IL': 'ILS',
    'IS': 'ISK',
  };

  static const List<String> supportedCurrencies = [
    'AUD', 'BGN', 'BRL', 'CAD', 'CHF', 'CNY', 'CZK', 'DKK',
    'EUR', 'GBP', 'HKD', 'HUF', 'IDR', 'ILS', 'INR', 'ISK',
    'JPY', 'KRW', 'MXN', 'MYR', 'NOK', 'NZD', 'PHP', 'PLN',
    'RON', 'SEK', 'SGD', 'THB', 'TRY', 'USD', 'ZAR',
  ];

  static const Map<String, String> currencyNames = {
    'AUD': 'Australian Dollar', 'BGN': 'Bulgarian Lev',
    'BRL': 'Brazilian Real', 'CAD': 'Canadian Dollar',
    'CHF': 'Swiss Franc', 'CNY': 'Chinese Yuan',
    'CZK': 'Czech Koruna', 'DKK': 'Danish Krone',
    'EUR': 'Euro', 'GBP': 'British Pound',
    'HKD': 'Hong Kong Dollar', 'HUF': 'Hungarian Forint',
    'IDR': 'Indonesian Rupiah', 'ILS': 'Israeli Shekel',
    'INR': 'Indian Rupee', 'ISK': 'Icelandic Króna',
    'JPY': 'Japanese Yen', 'KRW': 'South Korean Won',
    'MXN': 'Mexican Peso', 'MYR': 'Malaysian Ringgit',
    'NOK': 'Norwegian Krone', 'NZD': 'New Zealand Dollar',
    'PHP': 'Philippine Peso', 'PLN': 'Polish Złoty',
    'RON': 'Romanian Leu', 'SEK': 'Swedish Krona',
    'SGD': 'Singapore Dollar', 'THB': 'Thai Baht',
    'TRY': 'Turkish Lira', 'USD': 'US Dollar',
    'ZAR': 'South African Rand',
  };

  Future<Map<String, double>?> fetchRates(String baseCurrency) async {
    try {
      final uri = Uri.parse(
        'https://api.frankfurter.app/latest?from=$baseCurrency',
      );

      final response = await http.get(uri).timeout(const Duration(seconds: 8));

      if (response.statusCode != 200) {
        return null;
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final ratesRaw = json['rates'] as Map<String, dynamic>?;

      if (ratesRaw == null) {
        return null;
      }

      final rates = <String, double>{
        baseCurrency: 1.0,
        ...ratesRaw.map((key, value) => MapEntry(key, (value as num).toDouble())),
      };

      await _cacheRates(baseCurrency, rates);

      return rates;
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, double>?> getCachedRates(String baseCurrency) async {
    final cached = await storage.read(key: '${_cacheKey}_$baseCurrency');

    if (cached == null) {
      return null;
    }

    try {
      final json = jsonDecode(cached) as Map<String, dynamic>;
      final rates = (json['rates'] as Map<String, dynamic>)
          .map((key, value) => MapEntry(key, (value as num).toDouble()));

      return rates;
    } catch (_) {
      return null;
    }
  }

  Future<DateTime?> getCacheAge(String baseCurrency) async {
    final cached = await storage.read(key: '${_cacheKey}_$baseCurrency');

    if (cached == null) {
      return null;
    }

    try {
      final json = jsonDecode(cached) as Map<String, dynamic>;
      return DateTime.parse(json['fetchedAt'] as String);
    } catch (_) {
      return null;
    }
  }

  Future<void> _cacheRates(
    String baseCurrency,
    Map<String, double> rates,
  ) async {
    final data = jsonEncode({
      'fetchedAt': DateTime.now().toIso8601String(),
      'rates': rates,
    });

    await storage.write(key: '${_cacheKey}_$baseCurrency', value: data);
  }

  double convert(
    double amount,
    String from,
    String to,
    Map<String, double> rates,
  ) {
    if (from == to) {
      return amount;
    }

    final fromRate = rates[from] ?? 1.0;
    final toRate = rates[to] ?? 1.0;
    final base = rates.keys.first == from ? amount : amount / fromRate;

    return base * toRate;
  }
}
