// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Patrick Zwick

class PhoneLoginVerification {
  final String phoneNumber;
  final String code;
  final String? publicKey;

  PhoneLoginVerification({
    required this.phoneNumber,
    required this.code,
    this.publicKey,
  });

  Map<String, dynamic> toJson() {
    return {
      'phoneNumber': phoneNumber,
      'code': code,
      if (publicKey != null) 'publicKey': publicKey,
    };
  }
}
