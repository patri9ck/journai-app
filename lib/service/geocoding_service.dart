// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Patrick Zwick

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../model/location_info.dart';
import '../util/cache.dart';

class GeocodingService {
  static const _cacheKey = 'cache_geocoding';

  final String _contactEmail;
  final _countryCenters = <String, LatLng>{};

  GeocodingService({required String contactEmail}) : _contactEmail = contactEmail;

  Future<LocationInfo?> getCachedLocation() => _getCached();

  Future<LocationInfo?> reverseGeocode(double latitude, double longitude) async {
    try {
      final response = await http
          .get(
            Uri.parse(
              'https://nominatim.openstreetmap.org/reverse'
              '?lat=$latitude&lon=$longitude&format=json&accept-language=de',
            ),
            headers: {'User-Agent': 'JournaiApp/1.0 ($_contactEmail)'},
          )
          .timeout(const Duration(seconds: 8));

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
          .timeout(const Duration(seconds: 8));

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
