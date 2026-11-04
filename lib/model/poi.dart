// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Patrick Zwick

enum PoiType { hospital, pharmacy, police, fireStation, doctor }

class Poi {
  final PoiType type;
  final String name;
  final double latitude;
  final double longitude;

  const Poi({
    required this.type,
    required this.name,
    required this.latitude,
    required this.longitude,
  });

  static Poi? fromOverpass(Map<String, dynamic> element) {
    final center = element['center'] as Map<String, dynamic>?;
    final lat = ((element['lat'] ?? center?['lat']) as num?)?.toDouble();
    final lon = ((element['lon'] ?? center?['lon']) as num?)?.toDouble();
    final tags = element['tags'] as Map<String, dynamic>?;

    if (lat == null || lon == null || tags == null) {
      return null;
    }

    final amenity = tags['amenity'] as String? ?? '';
    final type = _typeFromAmenity(amenity);

    if (type == null) {
      return null;
    }

    final name = tags['name'] as String? ?? '';

    return Poi(
      type: type,
      name: name,
      latitude: lat,
      longitude: lon,
    );
  }

  static PoiType? _typeFromAmenity(String amenity) => switch (amenity) {
    'hospital' => PoiType.hospital,
    'pharmacy' => PoiType.pharmacy,
    'police' => PoiType.police,
    'fire_station' => PoiType.fireStation,
    'doctors' => PoiType.doctor,
    _ => null,
  };
}
