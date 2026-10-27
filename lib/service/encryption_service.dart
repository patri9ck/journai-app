// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Patrick Zwick

import '../model/result.dart';
import '../util/storage.dart';
import 'cryptography_service.dart';
import 'request_service.dart';

class EncryptionService {
  final RequestService _requestService;
  final CryptographyService _cryptographyService;

  EncryptionService({
    required RequestService requestService,
    required CryptographyService cryptographyService,
  }) : _requestService = requestService,
       _cryptographyService = cryptographyService;

  Future<bool> hasEncryptionSetup() async {
    final localKey = await storage.read(key: 'dataKey');

    if (localKey != null) {
      return true;
    }

    final result = await _requestService.getAuthenticatedRequest('user/encryption');

    if (result is! Success<Map<String, dynamic>>) {
      return false;
    }

    return result.value?['encryptedDataKey'] != null;
  }

  Future<Result<String?>> getEncryptedDataKey() async {
    final result = await _requestService.getAuthenticatedRequest('user/encryption');

    return mapResult(result, (json) => json['encryptedDataKey'] as String?);
  }

  Future<Result<void>> setupEncryption(String password) async {
    final encryptedDataKey = await _cryptographyService.setupEncryption(password);
    final result = await _requestService.postAuthenticatedRequest(
      'user/encryption',
      {'encryptedDataKey': encryptedDataKey},
    );

    if (result is Success) {
      await storage.write(key: 'encryptedDataKey', value: encryptedDataKey);
    } else {
      await storage.delete(key: 'dataKey');
    }

    return voidResult(result);
  }
}
