// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Patrick Zwick

class EmailLoginVerification {
  final String emailAddress;
  final String code;
  final String publicKey;

  EmailLoginVerification({
    required this.emailAddress,
    required this.code,
    required this.publicKey,
  });

  Map<String, dynamic> toJson() {
    return {'emailAddress': emailAddress, 'code': code, 'publicKey': publicKey};
  }
}
