// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Patrick Zwick

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:journai_app/model/contact/contact_type.dart';
import 'package:journai_app/model/login/login.dart';
import 'package:journai_app/model/result.dart';
import 'package:journai_app/service/apple_account_service.dart';
import 'package:journai_app/service/cryptography_service.dart';
import 'package:journai_app/service/google_account_service.dart';
import 'package:journai_app/service/login_service.dart';
import 'package:journai_app/service/request_service.dart';
import 'package:journai_app/util/storage.dart';

class _FakeRequestService extends RequestService {
  final List<(String method, String path, Map<String, dynamic> body)> calls = [];
  final Result<Map<String, dynamic>> result;

  _FakeRequestService(this.result) : super(baseUrl: '');

  @override
  Future<Result<Map<String, dynamic>>> postRequest(String path, Map<String, dynamic> body) async {
    calls.add(('POST', path, body));

    return result;
  }
}

void main() {
  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    await clearSession();
  });

  LoginService loginService(_FakeRequestService requests) => LoginService(
    requestService: requests,
    cryptographyService: CryptographyService(),
    googleAccountService: GoogleAccountService(serverClientId: ''),
    appleAccountService: AppleAccountService(),
  );

  test('requestLogin posts to the contact-specific endpoint with the field name', () async {
    final requests = _FakeRequestService(Success({}));
    final service = loginService(requests);

    expect(await service.requestLogin(ContactType.email, 'a@b.c'), isA<Success<void>>());
    expect(await service.requestLogin(ContactType.phone, '+4915123456789'), isA<Success<void>>());

    expect(requests.calls[0].$2, 'login/email');
    expect(requests.calls[0].$3, {'emailAddress': 'a@b.c'});
    expect(requests.calls[1].$2, 'login/phone');
    expect(requests.calls[1].$3, {'phoneNumber': '+4915123456789'});
  });

  test('requestRegistration includes the locale', () async {
    final requests = _FakeRequestService(Success({}));
    final service = loginService(requests);

    await service.requestRegistration(ContactType.email, 'a@b.c', 'de');

    expect(requests.calls.single.$2, 'register/email');
    expect(requests.calls.single.$3, {'emailAddress': 'a@b.c', 'locale': 'de'});
  });

  test('verifyLogin sends code and a fresh public key and stores the session', () async {
    final requests = _FakeRequestService(
      Success({
        'publicKey': 'server-public',
        'salt': 'salt',
        'accessToken': 'access',
        'refreshToken': 'refresh',
        'encryptedDataKey': 'encrypted-key',
        'deletionCancelled': true,
      }),
    );
    final service = loginService(requests);

    final result = await service.verifyLogin(ContactType.email, 'a@b.c', '123456');

    expect(result, isA<Success<Login>>());
    expect(requests.calls.single.$2, 'login/verify/email');
    expect(requests.calls.single.$3['code'], '123456');
    expect(requests.calls.single.$3['emailAddress'], 'a@b.c');
    expect((requests.calls.single.$3['publicKey'] as String).length, greaterThan(0));

    expect(await storage.read(key: 'accessToken'), 'access');
    expect(await storage.read(key: 'refreshToken'), 'refresh');
    expect(await storage.read(key: 'serverPublicKey'), 'server-public');
    expect(await storage.read(key: 'transferSalt'), 'salt');
    expect(await storage.read(key: 'encryptedDataKey'), 'encrypted-key');
    expect(await storage.read(key: 'deletion_cancelled_notification'), 'true');
  });

  test('verifyRegistration requires terms and maps failures', () async {
    final requests = _FakeRequestService(ServerFailure(message: 'm', key: 'terms-not-accepted', statusCode: 400));
    final service = loginService(requests);

    final result = await service.verifyRegistration(ContactType.phone, '+4915123456789', '123456', false);

    expect(result, isA<ServerFailure<Login>>().having((failure) => failure.key, 'key', 'terms-not-accepted'));
    expect(requests.calls.single.$2, 'register/verify/phone');
    expect(requests.calls.single.$3['termsAccepted'], false);
    expect(await storage.read(key: 'accessToken'), isNull);
  });

  test('login failures do not touch stored tokens', () async {
    await storage.write(key: 'accessToken', value: 'keep-me');

    final requests = _FakeRequestService(NetworkFailure());
    final service = loginService(requests);

    final result = await service.verifyLogin(ContactType.email, 'a@b.c', '123456');

    expect(result, isA<NetworkFailure<Login>>());
    expect(await storage.read(key: 'accessToken'), 'keep-me');
  });
}
