// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Patrick Zwick

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:journai_app/model/consent_type.dart';
import 'package:journai_app/model/contact/contact_type.dart';
import 'package:journai_app/model/limits.dart';
import 'package:journai_app/model/result.dart';
import 'package:journai_app/service/consent_service.dart';
import 'package:journai_app/service/contact_service.dart';
import 'package:journai_app/service/limits_service.dart';
import 'package:journai_app/service/request_service.dart';
import 'package:journai_app/util/cache.dart';
import 'package:journai_app/util/storage.dart';

class _FakeRequestService extends RequestService {
  final List<(String method, String path)> calls = [];
  final Map<String, Result<Map<String, dynamic>>> results;

  _FakeRequestService(this.results) : super(baseUrl: '');

  @override
  Future<Result<Map<String, dynamic>>> postAuthenticatedRequest(String path, Map<String, dynamic> body) async {
    calls.add(('POST', path));

    return results[path] ?? Success({});
  }

  @override
  Future<Result<Map<String, dynamic>>> getAuthenticatedRequest(String path) async {
    calls.add(('GET', path));

    return results[path] ?? Success({});
  }

  @override
  Future<Result<Map<String, dynamic>>> deleteAuthenticatedRequest(String path) async {
    calls.add(('DELETE', path));

    return results[path] ?? Success({});
  }
}

void main() {
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  group('ContactService', () {
    test('uses the contact-specific endpoints', () async {
      final requests = _FakeRequestService({});
      final service = ContactService(requestService: requests);

      await service.requestUpdate(ContactType.email, 'a@b.c');
      await service.verifyUpdate(ContactType.phone, '+4915123456789', '123456');
      await service.deleteContact(ContactType.phone);

      expect(requests.calls, [
        ('POST', 'update/email'),
        ('POST', 'update/verify/phone'),
        ('DELETE', 'user/phone'),
      ]);
    });

    test('server failures are passed through', () async {
      final requests = _FakeRequestService({
        'update/email': ServerFailure(message: 'm', key: 'user-already-registered', statusCode: 409),
      });
      final service = ContactService(requestService: requests);

      final result = await service.requestUpdate(ContactType.email, 'a@b.c');

      expect(result, isA<ServerFailure<void>>().having((failure) => failure.key, 'key', 'user-already-registered'));
    });
  });

  group('ConsentService', () {
    test('reads, gives and revokes consent per type', () async {
      final requests = _FakeRequestService({
        'user/consent/HEALTH_DATA_SCAN': Success({'hasConsent': true}),
        'user/consent/DOCUMENT_SCAN': Success({'hasConsent': false}),
      });
      final service = ConsentService(requestService: requests);

      expect(await service.hasConsent(ConsentType.healthDataScan), isTrue);
      expect(await service.hasConsent(ConsentType.documentScan), isFalse);

      await service.giveConsent(ConsentType.healthDataScan);
      await service.revokeConsent(ConsentType.documentScan);

      expect(requests.calls, [
        ('GET', 'user/consent/HEALTH_DATA_SCAN'),
        ('GET', 'user/consent/DOCUMENT_SCAN'),
        ('POST', 'user/consent/HEALTH_DATA_SCAN'),
        ('DELETE', 'user/consent/DOCUMENT_SCAN'),
      ]);
    });

    test('a failed consent request reads as no consent', () async {
      final requests = _FakeRequestService({
        'user/consent/HEALTH_DATA_SCAN': NetworkFailure(),
      });
      final service = ConsentService(requestService: requests);

      expect(await service.hasConsent(ConsentType.healthDataScan), isFalse);
    });
  });

  group('LimitsService', () {
    test('fetches, caches and falls back to cached limits', () async {
      final requests = _FakeRequestService({
        'user/limits': Success({
          'imageScans': 20,
          'tier': 'PRO',
          'profiles': 1,
          'features': {'VACCINE': 40},
        }),
      });
      final service = LimitsService(requestService: requests);

      final limits = await service.getLimits();

      expect(limits.imageScans, 20);
      expect(limits.tier, 'PRO');
      expect(limits.features['VACCINE'], 40);

      final cached = await service.getCachedLimits();

      expect(cached.tier, 'PRO');
      expect(requests.calls, [('GET', 'user/limits')]);
    });

    test('without a response the cached or unlimited limits are used', () async {
      await storage.delete(key: 'cache_limits');

      final requests = _FakeRequestService({'user/limits': NetworkFailure()});
      final service = LimitsService(requestService: requests);

      expect((await service.getLimits()).tier, Limits.unlimited.tier);

      await saveObjectCache('cache_limits', {'imageScans': 5, 'tier': 'FREE', 'profiles': 1, 'features': {}});

      expect((await service.getLimits()).tier, 'FREE');
    });
  });
}
