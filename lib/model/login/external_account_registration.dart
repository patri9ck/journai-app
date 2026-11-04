// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Patrick Zwick

class ExternalAccountRegistration {
  final String token;
  final String locale;
  final String publicKey;
  final bool termsAccepted;

  ExternalAccountRegistration({
    required this.token,
    required this.locale,
    required this.publicKey,
    required this.termsAccepted,
  });

  Map<String, dynamic> toJson() {
    return {'token': token, 'locale': locale, 'publicKey': publicKey, 'termsAccepted': termsAccepted};
  }
}
