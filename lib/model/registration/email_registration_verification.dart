// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Patrick Zwick

class EmailRegistrationVerification {
  final String emailAddress;
  final String code;
  final String publicKey;
  final bool termsAccepted;

  EmailRegistrationVerification({
    required this.emailAddress,
    required this.code,
    required this.publicKey,
    required this.termsAccepted,
  });

  Map<String, dynamic> toJson() => {
    'emailAddress': emailAddress,
    'code': code,
    'publicKey': publicKey,
    'termsAccepted': termsAccepted,
  };
}
