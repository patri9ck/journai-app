// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Patrick Zwick

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../model/location_info.dart';
import '../model/place_suggestion.dart';
import '../util/cache.dart';
import '../util/http_timeout.dart';

class GeocodingService {
  static const _cacheKey = 'cache_geocoding';

  static const _settlementTypes = {
    'city',
    'town',
    'village',
    'hamlet',
    'municipality',
    'borough',
    'suburb',
    'quarter',
    'neighbourhood',
    'district',
    'locality',
  };

  final String _contactEmail;
  final _countryCenters = <String, LatLng>{};
  final _cityCenters = <String, LatLng>{};
  final _placeSuggestions = <String, List<PlaceSuggestion>>{};

  GeocodingService({required String contactEmail}) : _contactEmail = contactEmail;

  Future<LocationInfo?> getCachedLocation() => _getCached();

  Future<LocationInfo?> reverseGeocode(double latitude, double longitude) async {
    final languageCode = WidgetsBinding.instance.platformDispatcher.locale.languageCode;

    try {
      final response = await http
          .get(
            Uri.parse(
              'https://nominatim.openstreetmap.org/reverse'
              '?lat=$latitude&lon=$longitude&format=json&accept-language=$languageCode',
            ),
            headers: {'User-Agent': 'JournaiApp/1.0 ($_contactEmail)'},
          )
          .timeout(httpTimeout);

      if (response.statusCode != 200) {
        return await _getCached();
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final address = json['address'] as Map<String, dynamic>?;

      if (address == null) {
        return await _getCached();
      }

      final city = address['city'] as String?
          ?? address['town'] as String?
          ?? address['village'] as String?
          ?? address['county'] as String?
          ?? '';
      final countryName = address['country'] as String? ?? '';
      final countryCode = (address['country_code'] as String? ?? '').toUpperCase();

      final info = LocationInfo(
        city: city,
        countryName: countryName,
        countryCode: countryCode,
      );

      await _saveCache(info);

      return info;
    } on IOException {
      return _getCached();
    } on http.ClientException {
      return _getCached();
    } on TimeoutException {
      return _getCached();
    } on FormatException {
      return _getCached();
    }
  }

  Future<LatLng?> getCityCenter(String city, String countryCode) async {
    final cacheKey = '${countryCode.toUpperCase()}|${city.trim().toLowerCase()}';
    final cached = _cityCenters[cacheKey];

    if (cached != null) {
      return cached;
    }

    for (final result in await _searchSettlements(city, countryCode)) {
      final latitude = result['lat'];
      final longitude = result['lon'];

      if (latitude is num && longitude is num) {
        return _cityCenters[cacheKey] = LatLng(latitude.toDouble(), longitude.toDouble());
      }
    }

    return null;
  }

  Future<List<PlaceSuggestion>> searchPlaces(String query, String countryCode) async {
    final trimmed = query.trim();

    if (trimmed.length < 2) {
      return [];
    }

    final cacheKey = '${countryCode.toUpperCase()}|${trimmed.toLowerCase()}';
    final cached = _placeSuggestions[cacheKey];

    if (cached != null) {
      return cached;
    }

    final suggestions = <PlaceSuggestion>[];

    for (final result in (await _searchSettlements(trimmed, countryCode)).take(10)) {
      final detail = [
        if (result['state'] case final String state when state.isNotEmpty) state,
        if (result['country'] case final String country when country.isNotEmpty) country,
      ].join(', ');

      suggestions.add(PlaceSuggestion(name: (result['name'] as String).trim(), detail: detail));
    }

    // Don't cache empty results: a rate-limited or failed request must not stick for the session.
    if (suggestions.isEmpty) {
      return suggestions;
    }

    return _placeSuggestions[cacheKey] = suggestions;
  }

  // Photon is an autocomplete geocoder over OSM data: partial input like "zagr" finds "Zagreb".
  // No "lang" parameter — Photon rejects unsupported language codes with HTTP 400.
  // Returns settlements of the given country as {name, lat, lon, state, country}, best matches first.
  Future<List<Map<String, dynamic>>> _searchSettlements(String query, String countryCode) async {
    final trimmed = query.trim();
    final lowered = trimmed.toLowerCase();
    final country = countryCode.toUpperCase();

    try {
      final response = await http
          .get(
            Uri.https('photon.komoot.io', '/api/', {'q': trimmed, 'limit': '25'}),
            headers: {'User-Agent': 'JournaiApp/1.0 ($_contactEmail)'},
          )
          .timeout(httpTimeout);

      if (response.statusCode != 200) {
        return [];
      }

      final features = (jsonDecode(response.body) as Map<String, dynamic>)['features'] as List? ?? [];
      final settlements = <Map<String, dynamic>>[];
      final seen = <String>{};

      for (final item in features) {
        if (item is! Map<String, dynamic>) {
          continue;
        }

        final properties = item['properties'] as Map<String, dynamic>? ?? {};
        final type = properties['type'] as String?;

        if (type != null && !_settlementTypes.contains(type)) {
          continue;
        }

        final code = properties['countrycode'] as String?;

        if (country.isNotEmpty && (code == null || code.toUpperCase() != country)) {
          continue;
        }

        final name = (properties['name'] as String?)?.trim() ?? '';

        if (name.isEmpty || !seen.add(name.toLowerCase())) {
          continue;
        }

        final coordinates = ((item['geometry'] as Map<String, dynamic>?)?['coordinates'] as List?) ?? [];

        settlements.add({
          'name': name,
          'lat': coordinates.length > 1 ? (coordinates[1] as num?)?.toDouble() : null,
          'lon': coordinates.isNotEmpty ? (coordinates[0] as num?)?.toDouble() : null,
          'state': properties['state'],
          'country': properties['country'],
        });
      }

      int rank(String name) {
        final normalized = name.toLowerCase();

        if (normalized == lowered) {
          return 0;
        }

        if (normalized.startsWith(lowered)) {
          return 1;
        }

        if (normalized.contains(lowered)) {
          return 2;
        }

        return 3;
      }

      // Stable sort by match rank, keeping Photon's relevance order within the same rank.
      final indexed = settlements.asMap().entries.toList();

      indexed.sort((first, second) {
        final comparison = rank(first.value['name'] as String).compareTo(rank(second.value['name'] as String));

        return comparison != 0 ? comparison : first.key.compareTo(second.key);
      });

      return [for (final entry in indexed) entry.value];
    } on IOException {
      return [];
    } on http.ClientException {
      return [];
    } on TimeoutException {
      return [];
    } on FormatException {
      return [];
    }
  }

  Future<LatLng?> getCountryCenter(String countryCode) async {
    final cached = _countryCenters[countryCode];

    if (cached != null) {
      return cached;
    }

    try {
      final response = await http
          .get(
            Uri.parse('https://nominatim.openstreetmap.org/search?country=$countryCode&featureType=country&format=json&limit=1'),
            headers: {'User-Agent': 'JournaiApp/1.0 ($_contactEmail)'},
          )
          .timeout(httpTimeout);

      if (response.statusCode != 200) {
        return null;
      }

      final results = jsonDecode(response.body) as List;

      if (results.isEmpty) {
        return null;
      }

      final result = results.first as Map<String, dynamic>;
      final latitude = double.tryParse(result['lat'] as String? ?? '');
      final longitude = double.tryParse(result['lon'] as String? ?? '');

      if (latitude == null || longitude == null) {
        return null;
      }

      return _countryCenters[countryCode] = LatLng(latitude, longitude);
    } on IOException {
      return null;
    } on http.ClientException {
      return null;
    } on TimeoutException {
      return null;
    } on FormatException {
      return null;
    }
  }

  Future<LocationInfo?> _getCached() async {
    final cached = await readObjectCache(_cacheKey);

    if (cached == null) {
      return null;
    }

    return LocationInfo(
      city: cached['city'] as String? ?? '',
      countryName: cached['countryName'] as String? ?? '',
      countryCode: cached['countryCode'] as String? ?? '',
    );
  }

  Future<void> _saveCache(LocationInfo info) async {
    await saveObjectCache(_cacheKey, {
      'city': info.city,
      'countryName': info.countryName,
      'countryCode': info.countryCode,
    });
  }
}
