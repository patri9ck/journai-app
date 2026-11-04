// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Patrick Zwick

class ExternalAccountLogin {
  final String token;
  final String publicKey;

  ExternalAccountLogin({required this.token, required this.publicKey});

  Map<String, dynamic> toJson() {
    return {'token': token, 'publicKey': publicKey};
  }
}
