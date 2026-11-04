// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Patrick Zwick

class Login {
  final String publicKey;
  final String salt;
  final String accessToken;
  final String refreshToken;
  final String? encryptedDataKey;
  final bool deletionCancelled;

  Login({
    required this.publicKey,
    required this.salt,
    required this.accessToken,
    required this.refreshToken,
    this.encryptedDataKey,
    this.deletionCancelled = false,
  });

  factory Login.fromJson(Map<String, dynamic> json) {
    return Login(
      publicKey: json['publicKey'] as String,
      salt: json['salt'] as String,
      accessToken: json['accessToken'] as String,
      refreshToken: json['refreshToken'] as String,
      encryptedDataKey: json['encryptedDataKey'] as String?,
      deletionCancelled: json['deletionCancelled'] as bool? ?? false,
    );
  }
}
