// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Patrick Zwick

import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

final storage = SecureStorage();

class SecureStorage {
  static const _attempts = 3;

  final _storage = FlutterSecureStorage(
    aOptions: const AndroidOptions(resetOnError: false),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  final _values = <String, String?>{};

  Future<String?> read({required String key}) async {
    if (_values.containsKey(key)) {
      return _values[key];
    }

    final (succeeded, value) = await _retry<String?>(() => _storage.read(key: key));

    if (succeeded) {
      _values[key] = value;
    }

    return value;
  }

  Future<void> write({required String key, required String? value}) async {
    _values.remove(key);

    final (succeeded, _) = await _retry<void>(() => _storage.write(key: key, value: value));

    if (succeeded) {
      _values[key] = value;
    }
  }

  Future<void> delete({required String key}) async {
    _values.remove(key);

    final (succeeded, _) = await _retry<void>(() => _storage.delete(key: key));

    if (succeeded) {
      _values[key] = null;
    }
  }

  Future<(bool, T?)> _retry<T>(Future<T> Function() operation) async {
    for (var attempt = 1; attempt <= _attempts; attempt++) {
      try {
        return (true, await operation());
      } on PlatformException {
        await Future.delayed(Duration(milliseconds: 100 * attempt));
      }
    }

    return (false, null);
  }
}

Future<void> clearSession() async {
  for (final key in [
    'accessToken',
    'refreshToken',
    'serverPublicKey',
    'transferSalt',
    'encryptedDataKey',
    'dataKey',
    'guestMode',
    'cache_data',
    'selected_profile',
    'publicKey',
    'privateKey',
    'cache_limits',
    'cache_user_info_email',
    'cache_user_info_phone',
    'cache_user_info_googleLinked',
    'cache_user_info_appleLinked',
    'cache_consent_health',
    'cache_consent_document',
    'deletion_cancelled_notification',
    'emergency_card_last_language',
  ]) {
    await storage.delete(key: key);
  }
}
