// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Patrick Zwick

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:journai_app/model/result.dart';
import 'package:journai_app/service/cryptography_service.dart';
import 'package:journai_app/service/encryption_service.dart';
import 'package:journai_app/service/request_service.dart';
import 'package:journai_app/util/storage.dart';

class _PostRequestService extends RequestService {
  final Result<Map<String, dynamic>> postResult;

  _PostRequestService(this.postResult) : super(baseUrl: '');

  @override
  Future<Result<Map<String, dynamic>>> postAuthenticatedRequest(
    String path,
    Map<String, dynamic> body, {
    Duration timeout = const Duration(seconds: 5),
  }) async => postResult;
}

void main() {
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  EncryptionService encryptionService(Result<Map<String, dynamic>> postResult) => EncryptionService(
    requestService: _PostRequestService(postResult),
    cryptographyService: CryptographyService(),
  );

  test('a key the server did not store is not kept on the device', () async {
    final result = await encryptionService(NetworkFailure()).setupEncryption('password');

    expect(result, isA<NetworkFailure<void>>());
    expect(await storage.read(key: 'dataKey'), isNull);
  });

  test('a key the server stored is kept on the device', () async {
    final result = await encryptionService(Success({})).setupEncryption('password');

    expect(result, isA<Success<void>>());
    expect(await storage.read(key: 'dataKey'), isNotNull);
    expect(await storage.read(key: 'encryptedDataKey'), isNotNull);
  });
}
