// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Patrick Zwick

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../model/country_content.dart';
import '../util/cache.dart';
import '../util/country_data.dart';
import '../util/http_timeout.dart';

class TravelWarning {
  final String countryGermanName;
  final bool hasWarning;
  final bool hasPartialWarning;
  final int? countryId;

  const TravelWarning({
    required this.countryGermanName,
    required this.hasWarning,
    required this.hasPartialWarning,
    this.countryId,
  });
}

class TravelWarningResult {
  final TravelWarning? warning;
  final bool networkError;

  const TravelWarningResult({this.warning, required this.networkError});
}

class TravelWarningService {
  static const _listCacheKey = 'cache_travel_warnings';
  static const _detailCachePrefix = 'cache_travel_detail_';

  static const _safetyKeywords = [
    'aktuell', 'sicherheit', 'warnung', 'kampf', 'innenpolitisch',
    'kriminal', 'natur und klima',
  ];
  static const _travelKeywords = [
    'reiseinfo', 'infrastruktur', 'verkehr', 'führerschein',
    'minderjährig', 'geld', 'kreditkarte',
  ];
  static const _entryKeywords = [
    'einreise', 'zoll', 'reisedokument', 'visum', 'biometr',
    'finanzierung', 'krankenversicherung', 'hiv-test', 'kfz',
    'aufenthalt', 'einfuhr', 'tiere',
  ];
  static const _healthKeywords = [
    'gesundheit', 'aids', 'meningoenzephalitis', 'tollwut',
    'radioaktiv', 'medizin',
  ];
  static const _legalKeywords = ['rechtliche besonderheit'];
  static const _lgbtqKeywords = ['lgbtiq', 'lgbtq', 'homosexual'];

  Future<TravelWarningResult?> getCachedWarningForCountry(String iso2CountryCode) async {
    final iso3 = iso2ToIso3[iso2CountryCode.toUpperCase()];

    if (iso3 == null) {
      return null;
    }

    final cached = await readListCache(_listCacheKey);

    if (cached == null) {
      return null;
    }

    return TravelWarningResult(
      warning: _findCountry(cached, iso3),
      networkError: false,
    );
  }

  Future<TravelWarningResult> getWarningForCountry(String iso2CountryCode) async {
    final iso3 = iso2ToIso3[iso2CountryCode.toUpperCase()];

    if (iso3 == null) {
      return const TravelWarningResult(networkError: false);
    }

    try {
      final response = await http
          .get(Uri.parse('https://www.auswaertiges-amt.de/opendata/travelwarning'))
          .timeout(httpTimeout);

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        final items = _parseItems(json);

        if (items != null) {
          await saveListCache(_listCacheKey, items);
          return TravelWarningResult(
            warning: _findCountry(items, iso3),
            networkError: false,
          );
        }
      }

      final cached = await readListCache(_listCacheKey);

      if (cached != null) {
        return TravelWarningResult(
          warning: _findCountry(cached, iso3),
          networkError: false,
        );
      }

      return const TravelWarningResult(networkError: false);
    } on IOException {
      final cached = await readListCache(_listCacheKey);

      return TravelWarningResult(
        warning: cached != null ? _findCountry(cached, iso3) : null,
        networkError: cached == null,
      );
    } on http.ClientException {
      final cached = await readListCache(_listCacheKey);

      return TravelWarningResult(
        warning: cached != null ? _findCountry(cached, iso3) : null,
        networkError: cached == null,
      );
    } on TimeoutException {
      final cached = await readListCache(_listCacheKey);

      return TravelWarningResult(
        warning: cached != null ? _findCountry(cached, iso3) : null,
        networkError: cached == null,
      );
    } on FormatException {
      final cached = await readListCache(_listCacheKey);

      return TravelWarningResult(
        warning: cached != null ? _findCountry(cached, iso3) : null,
        networkError: cached == null,
      );
    }
  }

  Future<CountryContent?> getCachedCountryContent(int countryId) async {
    final cached = await readObjectCache('$_detailCachePrefix$countryId');
    return cached != null ? CountryContent.fromJson(cached) : null;
  }

  Future<CountryContent?> getCountryContent(int countryId) async {
    final cacheKey = '$_detailCachePrefix$countryId';

    CountryContent? fetched;

    try {
      final response = await http
          .get(
            Uri.parse(
              'https://www.auswaertiges-amt.de/opendata/travelwarning/$countryId',
            ),
          )
          .timeout(httpTimeout);

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        final entry = (json['response'] as Map<String, dynamic>?)?[
            countryId.toString()] as Map<String, dynamic>?;

        final html = entry?['content'] as String?;

        if (html != null) {
          fetched = _groupSections(_parseSections(html));
          await saveObjectCache(cacheKey, fetched.toJson());
        }
      }
    } on IOException {
      fetched = null;
    } on http.ClientException {
      fetched = null;
    } on TimeoutException {
      fetched = null;
    } on FormatException {
      fetched = null;
    }

    if (fetched != null) {
      return fetched;
    }

    final cached = await readObjectCache(cacheKey);
    return cached != null ? CountryContent.fromJson(cached) : null;
  }

  String translatedCacheKey(int countryId, String locale) =>
      '$_detailCachePrefix${countryId}_$locale';

  static String hashContent(CountryContent content) {
    final parts = [
      content.safety,
      content.travel,
      content.entry,
      content.health,
      content.legal,
      content.lgbtq,
    ].whereType<String>().toList();

    var hash = 0;

    for (final part in parts) {
      for (final rune in part.runes) {
        hash = (hash * 31 + rune) & 0x7FFFFFFF;
      }
      hash = (hash * 31 + 0x21) & 0x7FFFFFFF;
    }

    return hash.toString();
  }

  Map<String, String> _parseSections(String html) {
    final sections = <String, String>{};
    final pattern = RegExp(
      r'<h[23][^>]*>(.*?)</h[23]>(.*?)(?=<h[23]|$)',
      dotAll: true,
      caseSensitive: false,
    );

    for (final match in pattern.allMatches(html)) {
      final header = _stripTags(match.group(1) ?? '').trim();
      final body = _extractBullets(match.group(2) ?? '');

      if (header.isNotEmpty && body.isNotEmpty) {
        sections[header] = body;
      }
    }

    return sections;
  }

  CountryContent _groupSections(Map<String, String> sections) {
    String? extract(List<String> keywords) {
      final bullets = <String>[];

      for (final entry in sections.entries) {
        if (keywords.any((keyword) => entry.key.toLowerCase().contains(keyword))) {
          bullets.addAll(entry.value.split('\n').where((line) => line.isNotEmpty));
        }
      }

      return bullets.isEmpty ? null : bullets.join('\n');
    }

    return CountryContent(
      safety: extract(_safetyKeywords),
      travel: extract(_travelKeywords),
      entry: extract(_entryKeywords),
      health: extract(_healthKeywords),
      legal: extract(_legalKeywords),
      lgbtq: extract(_lgbtqKeywords),
    );
  }

  String _extractBullets(String html) {
    final liPattern = RegExp(r'<li[^>]*>(.*?)</li>', dotAll: true, caseSensitive: false);
    final bullets = liPattern
        .allMatches(html)
        .map((match) => '- ${_stripTags(match.group(1) ?? '').trim()}')
        .where((bullet) {
          if (bullet.length <= 2) {
            return false;
          }

          final text = bullet.substring(2).trim();

          if (text.endsWith(',') || text.endsWith(';')) {
            return false;
          }

          if (text.toLowerCase().contains('beachten sie auch')) {
            return false;
          }

          return true;
        })
        .toList();

    return bullets.join('\n');
  }

  String _stripTags(String html) {
    return html
        .replaceAll(RegExp(r'<[^>]+>'), '')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  List<Map<String, dynamic>>? _parseItems(Map<String, dynamic> json) {
    try {
      final response = json['response'] as Map<String, dynamic>?;

      if (response == null) {
        return null;
      }

      final contentList = response['contentList'] as List?;

      if (contentList == null) {
        return null;
      }

      final items = <Map<String, dynamic>>[];

      for (final id in contentList) {
        final entry = response[id.toString()];

        if (entry is Map<String, dynamic>) {
          items.add({...entry, '_id': id.toString()});
        }
      }

      return items.isEmpty ? null : items;
    } on TypeError {
      return null;
    }
  }

  TravelWarning? _findCountry(List<Map<String, dynamic>> items, String iso3) {
    for (final item in items) {
      final code = (item['iso3CountryCode'] as String? ?? '').toUpperCase();

      if (code == iso3.toUpperCase()) {
        return TravelWarning(
          countryGermanName: item['countryName'] as String? ?? '',
          hasWarning: item['warning'] as bool? ?? false,
          hasPartialWarning: item['partialWarning'] as bool? ?? false,
          countryId: int.tryParse(item['_id'] as String? ?? ''),
        );
      }
    }

    return null;
  }
}
