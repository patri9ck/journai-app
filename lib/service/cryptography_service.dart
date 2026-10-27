// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Patrick Zwick

import 'dart:convert';
import 'dart:math' show Random;
import 'dart:typed_data';

import 'package:cryptography_plus/cryptography_plus.dart';
import '../util/storage.dart';

class CryptographyService {
  final _x25519 = X25519();
  final _aesGcm = AesGcm.with256bits();
  final _hkdf = Hkdf(hmac: Hmac.sha256(), outputLength: 32);

  Future<String> generateKeyPair() async {
    final keyPair = await _x25519.newKeyPair();
    final publicKeyBytes = (await keyPair.extractPublicKey()).bytes;
    final privateKeyBytes = await keyPair.extractPrivateKeyBytes();
    final publicKey = base64Encode(publicKeyBytes);
    await storage.write(key: 'publicKey', value: publicKey);
    await storage.write(key: 'privateKey', value: base64Encode(privateKeyBytes));
    return publicKey;
  }

  Future<SecretKey> deriveTransferKey(
      String serverPublicKeyBase64, String saltBase64) async {
    final clientPrivateKeyBytes =
        base64Decode((await storage.read(key: 'privateKey'))!);
    final clientPublicKeyBytes =
        base64Decode((await storage.read(key: 'publicKey'))!);
    final serverPublicKeyBytes = base64Decode(serverPublicKeyBase64);
    final saltBytes = base64Decode(saltBase64);

    final keyPair = SimpleKeyPairData(
      clientPrivateKeyBytes,
      publicKey:
          SimplePublicKey(clientPublicKeyBytes, type: KeyPairType.x25519),
      type: KeyPairType.x25519,
    );

    final sharedSecret = await _x25519.sharedSecretKey(
      keyPair: keyPair,
      remotePublicKey:
          SimplePublicKey(serverPublicKeyBytes, type: KeyPairType.x25519),
    );

    return await _hkdf.deriveKey(secretKey: sharedSecret, nonce: saltBytes);
  }

  Future<String> encryptForTransfer(Uint8List data, SecretKey key) async {
    final secretBox = await _aesGcm.encrypt(data, secretKey: key);
    return base64Encode(secretBox.concatenation());
  }

  Future<Uint8List> decryptFromTransfer(
      String encryptedBase64, SecretKey key) async {
    return Uint8List.fromList(await _decrypt(encryptedBase64, key));
  }

  Future<String> setupEncryption(String password) async {
    final salt = _randomBytes(32);
    final dataKey = _randomBytes(32);
    final derivedKey = await _deriveKeyFromPassword(password, salt);
    final secretBox =
        await _aesGcm.encrypt(dataKey, secretKey: derivedKey);
    await storage.write(key: 'dataKey', value: base64Encode(dataKey));
    return base64Encode([
      ...salt,
      ...secretBox.nonce,
      ...secretBox.cipherText,
      ...secretBox.mac.bytes,
    ]);
  }

  Future<bool> unlockEncryption(
      String encryptedDataKeyBase64, String password) async {
    try {
      final bytes = base64Decode(encryptedDataKeyBase64);
      final salt = bytes.sublist(0, 32);
      final rest = bytes.sublist(32);
      final nonce = rest.sublist(0, 12);
      final cipherText = rest.sublist(12, rest.length - 16);
      final mac = rest.sublist(rest.length - 16);
      final derivedKey = await _deriveKeyFromPassword(password, salt);
      final secretBox = SecretBox(cipherText, nonce: nonce, mac: Mac(mac));
      final dataKey =
          await _aesGcm.decrypt(secretBox, secretKey: derivedKey);
      await storage.write(key: 'dataKey', value: base64Encode(dataKey));
      return true;
    } on SecretBoxAuthenticationError {
      return false;
    }
  }

  Future<String> encryptData(String jsonData) async {
    final dataKey = (await readDataKey())!;
    final secretBox =
        await _aesGcm.encrypt(utf8.encode(jsonData), secretKey: dataKey);
    return base64Encode(secretBox.concatenation());
  }

  Future<SecretKey?> readDataKey() async {
    final dataKeyBase64 = await storage.read(key: 'dataKey');

    if (dataKeyBase64 == null) {
      return null;
    }

    return SecretKey(base64Decode(dataKeyBase64));
  }

  Future<String> decryptData(String encryptedBase64, SecretKey dataKey) async {
    return utf8.decode(await _decrypt(encryptedBase64, dataKey));
  }

  Future<List<int>> _decrypt(String encryptedBase64, SecretKey key) {
    final secretBox = SecretBox.fromConcatenation(
      base64Decode(encryptedBase64),
      nonceLength: 12,
      macLength: 16,
      copy: false,
    );
    return _aesGcm.decrypt(secretBox, secretKey: key);
  }

  Future<SecretKey> _deriveKeyFromPassword(
      String password, List<int> salt) async {
    final pbkdf2 =
        Pbkdf2(macAlgorithm: Hmac.sha256(), iterations: 100000, bits: 256);
    return await pbkdf2.deriveKey(
        secretKey: SecretKey(utf8.encode(password)), nonce: salt);
  }

  Future<String?> reEncryptUnlockedDataKey(String newPassword) async {
    final dataKeyBase64 = await storage.read(key: 'dataKey');

    if (dataKeyBase64 == null) {
      return null;
    }

    final dataKeyBytes = base64Decode(dataKeyBase64);
    final salt = _randomBytes(32);
    final derivedKey = await _deriveKeyFromPassword(newPassword, salt);
    final secretBox = await _aesGcm.encrypt(dataKeyBytes, secretKey: derivedKey);

    final newEncryptedDataKey = base64Encode([
      ...salt,
      ...secretBox.nonce,
      ...secretBox.cipherText,
      ...secretBox.mac.bytes,
    ]);

    await storage.write(key: 'encryptedDataKey', value: newEncryptedDataKey);

    return newEncryptedDataKey;
  }

  List<int> _randomBytes(int length) =>
      List<int>.generate(length, (_) => Random.secure().nextInt(256));
}
