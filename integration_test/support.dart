// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Patrick Zwick

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:cryptography_plus/cryptography_plus.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geolocator_platform_interface/geolocator_platform_interface.dart';
import 'package:journai_app/service/overpass_service.dart';
import 'package:journai_app/util/cache.dart';
import 'package:journai_app/util/navigator_key.dart';
import 'package:journai_app/util/storage.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

const _latitude = 48.8566;
const _longitude = 2.3522;

Position parisPosition() => Position(
  latitude: _latitude,
  longitude: _longitude,
  timestamp: DateTime.now(),
  accuracy: 5,
  altitude: 0,
  altitudeAccuracy: 0,
  heading: 0,
  headingAccuracy: 0,
  speed: 0,
  speedAccuracy: 0,
);

class MockGeolocator extends GeolocatorPlatform with MockPlatformInterfaceMixin {
  @override
  Future<bool> isLocationServiceEnabled() => Future.value(true);

  @override
  Future<LocationPermission> checkPermission() => Future.value(LocationPermission.always);

  @override
  Future<LocationPermission> requestPermission() => Future.value(LocationPermission.always);

  @override
  Future<Position?> getLastKnownPosition({bool forceLocationManager = false}) =>
      Future.value(parisPosition());

  @override
  Future<Position> getCurrentPosition({LocationSettings? locationSettings}) =>
      Future.value(parisPosition());

  @override
  Stream<Position> getPositionStream({LocationSettings? locationSettings}) =>
      Stream.value(parisPosition());
}

final tripStart = DateTime.now().add(const Duration(days: 60));

const _memories = [
  (11, 'TRIP', {'countryCode': 'NO', 'countryName': 'Norway', 'start': '2025-01-12', 'end': '2025-01-16'}),
  (12, 'TRIP', {'countryCode': 'PT', 'countryName': 'Portugal', 'start': '2025-06-07', 'end': '2025-06-12'}),
  (13, 'TRIP', {'countryCode': 'JP', 'countryName': 'Japan', 'start': '2026-04-04', 'end': '2026-04-13'}),
  (14, 'JOURNAL_ENTRY', {'tripId': 13, 'date': '2026-04-04', 'text': 'Landed in Tokyo. Ramen at midnight in Shinjuku.'}),
  (15, 'JOURNAL_ENTRY', {'tripId': 13, 'date': '2026-04-08', 'text': 'Rain on the temple roofs in Kyoto. The moss smelled of wood.', 'sound': 'AAAA'}),
  (16, 'TICKET', {'title': 'Shinkansen Tokyo - Kyoto', 'date': '2026-04-07'}),
  (17, 'RECEIPT', {'merchant': 'Ichiran Ramen', 'amount': 1180, 'currency': 'JPY', 'date': '2026-04-04', 'category': 'OTHER'}),
  (18, 'TIME_CAPSULE', {'tripId': 13, 'text': 'Go back to Kyoto.', 'writtenAt': '2026-04-08', 'opensAt': '2027-04-08'}),
];

Future<void> seedDemoData() async {
  GeolocatorPlatform.instance = MockGeolocator();
  OverpassService.disableNetworkForTesting = true;

  final demoKey = Uint8List.fromList(List.generate(32, (i) => i + 1));
  await storage.write(key: 'dataKey', value: base64Encode(demoKey));
  await storage.write(key: 'accessToken', value: 'screenshot-demo');
  await storage.write(key: 'refreshToken', value: 'screenshot-demo');
  await storage.write(
    key: 'trial_popup_next_show',
    value: DateTime.now().add(const Duration(days: 365)).millisecondsSinceEpoch.toString(),
  );
  await storage.write(key: 'push_notification_accepted', value: 'true');

  await saveObjectCache('cache_limits', {
    'imageScans': 20,
    'tier': 'PRO',
    'profiles': 1,
    'features': {'ENTRY_CHECK': 1, 'TRAVEL_WARNING_ALERTS': 1, 'TRIP': 20, 'RECEIPT': 100, 'JOURNAL_ENTRY': 600, 'TIME_CAPSULE': 20},
  });

  await saveObjectCache('cache_entry_check_THA', {
    'countryCode': 'THA',
    'countryName': 'Thailand',
    'sourceUrl': 'https://www.auswaertiges-amt.de/de/ReiseUndSicherheit/201558',
    'sourceUpdatedAt': tripStart.subtract(const Duration(days: 90)).millisecondsSinceEpoch ~/ 1000,
    'requirements': {
      'passportValidityMonths': 6,
      'visaFreeDays': 60,
      'forms': [
        {'name': 'Thailand Digital Arrival Card (TDAC)', 'url': 'https://tdac.immigration.go.th', 'mandatory': true},
      ],
      'requiredVaccines': [
        {'disease': 'YELLOW_FEVER', 'onlyWhenArrivingFromRiskArea': true},
      ],
      'recommendedVaccines': ['HEPATITIS_A', 'RABIES', 'JAPANESE_ENCEPHALITIS'],
    },
  });

  await saveObjectCache('cache_geocoding', {
    'city': 'Paris',
    'countryName': 'France',
    'countryCode': 'FR',
  });

  await saveObjectCache('cache_overpass_pois', {
    'lat': _latitude,
    'lon': _longitude,
    'elements': [
      {
        'lat': _latitude + 0.002,
        'lon': _longitude + 0.001,
        'tags': {'amenity': 'hospital', 'name': 'Hôpital Saint-Louis'},
      },
      {
        'lat': _latitude - 0.001,
        'lon': _longitude + 0.003,
        'tags': {'amenity': 'pharmacy', 'name': 'Pharmacie du Centre'},
      },
      {
        'lat': _latitude + 0.003,
        'lon': _longitude - 0.002,
        'tags': {'amenity': 'police', 'name': 'Commissariat de Police'},
      },
      {
        'lat': _latitude - 0.002,
        'lon': _longitude - 0.001,
        'tags': {'amenity': 'fire_station', 'name': 'Caserne de Pompiers'},
      },
      {
        'lat': _latitude + 0.001,
        'lon': _longitude - 0.003,
        'tags': {'amenity': 'doctors', 'name': 'Cabinet Médical'},
      },
    ],
  });

  final aesGcm = AesGcm.with256bits();
  final secretKey = SecretKey(demoKey);

  Future<String> encrypt(Map<String, dynamic> payload) async {
    final box = await aesGcm.encrypt(
      utf8.encode(jsonEncode(payload)),
      secretKey: secretKey,
    );
    return base64Encode([...box.nonce, ...box.cipherText, ...box.mac.bytes]);
  }

  await saveListCache('cache_data', [
    {
      'id': 1,
      'feature': 'VACCINE',
      'data': await encrypt({
        'feature': 'VACCINE',
        'fields': {
          'name': 'COVID-19 (Comirnaty)',
          'disease': 'COVID-19',
          'date': '2024-03-15',
          'nextDate': '2027-03-15',
          'manufacturer': 'BioNTech / Pfizer',
          'batchNumber': 'EW0553',
        },
      }),
    },
    {
      'id': 2,
      'feature': 'VACCINE',
      'data': await encrypt({
        'feature': 'VACCINE',
        'fields': {
          'name': 'Tetanus (Td-pur)',
          'disease': 'Tetanus',
          'date': '2022-08-10',
          'nextDate': '2032-08-10',
          'manufacturer': 'Sanofi Pasteur',
        },
      }),
    },
    {
      'id': 3,
      'feature': 'VACCINE',
      'data': await encrypt({
        'feature': 'VACCINE',
        'fields': {
          'name': 'Hepatitis A (Havrix)',
          'disease': 'Hepatitis A',
          'date': '2023-05-20',
          'nextDate': '2033-05-20',
          'manufacturer': 'GlaxoSmithKline',
        },
      }),
    },
    {
      'id': 4,
      'feature': 'VACCINE',
      'data': await encrypt({
        'feature': 'VACCINE',
        'fields': {
          'name': 'Yellow Fever (Stamaril)',
          'disease': 'Yellow Fever',
          'date': '2023-11-05',
          'nextDate': '2033-11-05',
          'manufacturer': 'Sanofi Pasteur',
          'batchNumber': 'U4851-2',
        },
      }),
    },
    {
      'id': 5,
      'feature': 'ALLERGY',
      'data': await encrypt({
        'feature': 'ALLERGY',
        'fields': {'name': 'Penicillin', 'severity': 'SEVERE'},
      }),
    },
    {
      'id': 6,
      'feature': 'ALLERGY',
      'data': await encrypt({
        'feature': 'ALLERGY',
        'fields': {'name': 'Peanuts', 'severity': 'MODERATE'},
      }),
    },
    {
      'id': 7,
      'feature': 'BLOOD_TYPE',
      'data': await encrypt({
        'feature': 'BLOOD_TYPE',
        'fields': {'key': 'Blood Type', 'value': 'A+'},
      }),
    },
    {
      'id': 8,
      'feature': 'PASSPORT',
      'data': await encrypt({
        'feature': 'PASSPORT',
        'fields': {'expiryDate': tripStart.add(const Duration(days: 900)).toIso8601String().substring(0, 10)},
      }),
    },
    {
      'id': 9,
      'feature': 'TRIP',
      'data': await encrypt({
        'feature': 'TRIP',
        'fields': {
          'countryCode': 'TH',
          'countryName': 'Thailand',
          'start': tripStart.toIso8601String().substring(0, 10),
          'end': tripStart.add(const Duration(days: 14)).toIso8601String().substring(0, 10),
        },
      }),
    },
    {
      'id': 10,
      'feature': 'RECEIPT',
      'data': await encrypt({
        'feature': 'RECEIPT',
        'fields': {'merchant': 'Bangkok Hospital', 'amount': 1200, 'currency': 'THB', 'category': 'HOSPITAL'},
      }),
    },
    for (final (id, feature, fields) in _memories)
      {'id': id, 'feature': feature, 'data': await encrypt({'feature': feature, 'fields': fields})},
  ]);
}

Future<void> pumpFor(WidgetTester tester, Duration duration) async {
  final end = DateTime.now().add(duration);

  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<bool> waitFor(WidgetTester tester, Finder finder, {Duration timeout = const Duration(seconds: 15)}) async {
  final end = DateTime.now().add(timeout);

  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 200));

    if (finder.evaluate().isNotEmpty) {
      return true;
    }
  }

  return false;
}

Future<void> back(WidgetTester tester) async {
  navigatorKey.currentState!.pop();
  await pumpFor(tester, const Duration(seconds: 1));
}
