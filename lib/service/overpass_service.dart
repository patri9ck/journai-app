// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Patrick Zwick

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

import '../model/poi.dart';
import '../util/cache.dart';
import '../util/http_timeout.dart';

class OverpassService {
  static const _cacheKey = 'cache_overpass_pois';
  static const _radiusMeters = 5000;
  static const _cacheRadiusMeters = 3000;
  static const _attempts = 4;
  static const _retryStatusCodes = {429, 502, 503, 504};

  static bool disableNetworkForTesting = false;

  final Map<String, String> _headers;

  OverpassService({required String contactEmail})
      : _headers = {'User-Agent': 'JournaiApp/1.0 ($contactEmail)'};

  Future<List<Poi>> getCachedPois(double latitude, double longitude) async {
    final cached = await readObjectCache(_cacheKey);
    final cachedLatitude = (cached?['lat'] as num?)?.toDouble();
    final cachedLongitude = (cached?['lon'] as num?)?.toDouble();

    if (cached == null || cachedLatitude == null || cachedLongitude == null) {
      return [];
    }

    final distance = Geolocator.distanceBetween(latitude, longitude, cachedLatitude, cachedLongitude);

    if (distance > _cacheRadiusMeters) {
      return [];
    }

    return _parse(cached['elements']);
  }

  Future<List<Poi>?> getNearbyPois(double latitude, double longitude) async {
    if (disableNetworkForTesting) {
      return getCachedPois(latitude, longitude);
    }

    final query =
        '[out:json][timeout:50];'
        'nwr[amenity~"^(hospital|pharmacy|police|fire_station|doctors)\$"]'
        '(around:$_radiusMeters,$latitude,$longitude);'
        'out center 300;';
    final uri = Uri.parse('https://overpass-api.de/api/interpreter?data=${Uri.encodeComponent(query)}');

    for (var attempt = 1; attempt <= _attempts; attempt++) {
      final response = await _get(uri);

      if (response?.statusCode == 200) {
        return _parseResponse(latitude, longitude, response!.body);
      }

      if (response != null && !_retryStatusCodes.contains(response.statusCode)) {
        return null;
      }

      if (attempt < _attempts) {
        await Future.delayed(Duration(seconds: 2 * attempt));
      }
    }

    return null;
  }

  Future<http.Response?> _get(Uri uri) async {
    try {
      return await http.get(uri, headers: _headers).timeout(httpTimeout);
    } on IOException {
      return null;
    } on http.ClientException {
      return null;
    } on TimeoutException {
      return null;
    }
  }

  Future<List<Poi>?> _parseResponse(double latitude, double longitude, String body) async {
    try {
      final elements = (jsonDecode(body) as Map<String, dynamic>)['elements'];

      await _saveCache(latitude, longitude, elements);

      return _parse(elements);
    } on FormatException {
      return null;
    }
  }

  List<Poi> _parse(Object? elements) => (elements as List? ?? [])
      .whereType<Map<String, dynamic>>()
      .map(Poi.fromOverpass)
      .whereType<Poi>()
      .toList();

  Future<void> _saveCache(double latitude, double longitude, Object? elements) async {
    await saveObjectCache(_cacheKey, {
      'lat': latitude,
      'lon': longitude,
      'elements': elements,
    });
  }
}
