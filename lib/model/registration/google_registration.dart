// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Patrick Zwick

class GoogleRegistration {
  final String token;
  final String locale;
  final String publicKey;
  final bool termsAccepted;

  GoogleRegistration({
    required this.token,
    required this.locale,
    required this.publicKey,
    required this.termsAccepted,
  });

  Map<String, dynamic> toJson() => {
    'token': token,
    'locale': locale,
    'publicKey': publicKey,
    'termsAccepted': termsAccepted,
  };
}
