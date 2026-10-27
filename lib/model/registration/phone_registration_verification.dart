// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Patrick Zwick

class PhoneRegistrationVerification {
  final String phoneNumber;
  final String code;
  final String publicKey;
  final bool termsAccepted;

  PhoneRegistrationVerification({
    required this.phoneNumber,
    required this.code,
    required this.publicKey,
    required this.termsAccepted,
  });

  Map<String, dynamic> toJson() => {
    'phoneNumber': phoneNumber,
    'code': code,
    'publicKey': publicKey,
    'termsAccepted': termsAccepted,
  };
}
