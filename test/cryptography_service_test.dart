// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Patrick Zwick

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:journai_app/service/cryptography_service.dart';
import 'package:journai_app/util/storage.dart';

void main() {
  final cryptographyService = CryptographyService();

  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  test('data can only be decrypted with the right password', () async {
    final encryptedDataKey = await cryptographyService.setupEncryption('correct horse');
    final encrypted = await cryptographyService.encryptData('{"name":"Hepatitis A"}');

    await storage.delete(key: 'dataKey');

    expect(await cryptographyService.unlockEncryption(encryptedDataKey, 'wrong password'), isFalse);
    expect(await cryptographyService.unlockEncryption(encryptedDataKey, 'correct horse'), isTrue);
    expect(await cryptographyService.decryptData(encrypted), '{"name":"Hepatitis A"}');
  });

  test('changing the password keeps existing data readable', () async {
    await cryptographyService.setupEncryption('old password');
    final encrypted = await cryptographyService.encryptData('passport');
    final newEncryptedDataKey = await cryptographyService.reEncryptUnlockedDataKey('new password');

    await storage.delete(key: 'dataKey');

    expect(await cryptographyService.unlockEncryption(newEncryptedDataKey!, 'old password'), isFalse);
    expect(await cryptographyService.unlockEncryption(newEncryptedDataKey, 'new password'), isTrue);
    expect(await cryptographyService.decryptData(encrypted), 'passport');
  });

  test('every encryption uses a fresh nonce', () async {
    await cryptographyService.setupEncryption('password');

    expect(await cryptographyService.encryptData('same'), isNot(await cryptographyService.encryptData('same')));
  });
}
