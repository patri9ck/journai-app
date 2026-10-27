// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Patrick Zwick

import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:journai_app/model/result.dart';
import 'package:journai_app/service/cryptography_service.dart';
import 'package:journai_app/service/data_service.dart';
import 'package:journai_app/service/request_service.dart';
import 'package:journai_app/util/cache.dart';
import 'package:journai_app/util/profile_notifier.dart';

class _DeleteRequestService extends RequestService {
  final Result<Map<String, dynamic>> deleteResult;

  _DeleteRequestService(this.deleteResult) : super(baseUrl: '');

  @override
  Future<Result<Map<String, dynamic>>> deleteAuthenticatedRequest(String path) async => deleteResult;
}

void main() {
  final cryptographyService = CryptographyService();
  final dataService = DataService(requestService: RequestService(baseUrl: ''), cryptographyService: cryptographyService);

  Future<Map<String, dynamic>> entry(int id, String feature, Map<String, dynamic> fields, {int? profileId}) async => {
    'id': id,
    'feature': feature,
    'data': await cryptographyService.encryptData(
      jsonEncode({'feature': feature, 'fields': fields, 'profileId': ?profileId}),
    ),
  };

  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    await cryptographyService.setupEncryption('password');

    await saveListCache('cache_data', [
      await entry(1, 'VACCINE', {'name': 'Mine'}),
      await entry(2, 'PROFILE', {'name': 'Mia'}),
      await entry(3, 'VACCINE', {'name': 'Mia vaccine'}, profileId: 2),
    ]);
  });

  tearDown(() => selectProfile(null));

  test('only entries of the selected profile are returned', () async {
    await selectProfile(null);

    expect((await dataService.getCachedData()).map((data) => data.id), [1]);

    await selectProfile(2);

    expect((await dataService.getCachedData()).map((data) => data.id), [3]);
  });

  test('profiles are only returned when asked for', () async {
    expect((await dataService.getCachedData(['PROFILE'])).map((data) => data.fields['name']), ['Mia']);
    expect((await dataService.getCachedData(['VACCINE'])).map((data) => data.id), [1]);
  });

  test('expiry reminders see the entries of all profiles', () async {
    expect((await dataService.getCachedDataOfAllProfiles()).map((data) => data.id), [1, 3]);
  });

  test('a failed delete keeps the offline cache', () async {
    final offlineDataService = DataService(
      requestService: _DeleteRequestService(NetworkFailure()),
      cryptographyService: cryptographyService,
    );

    expect(await offlineDataService.deleteData(1), isA<NetworkFailure<void>>());
    expect((await offlineDataService.getCachedData()).map((data) => data.id), [1]);
  });

  test('a successful delete removes only that entry from the cache', () async {
    final onlineDataService = DataService(
      requestService: _DeleteRequestService(Success({})),
      cryptographyService: cryptographyService,
    );

    expect(await onlineDataService.deleteData(1), isA<Success<void>>());
    expect((await onlineDataService.getCachedDataOfAllProfiles()).map((data) => data.id), [3]);
  });
}
