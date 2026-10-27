// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Patrick Zwick

class AppleLogin {
  final String token;
  final String publicKey;

  AppleLogin({required this.token, required this.publicKey});

  Map<String, dynamic> toJson() => {'token': token, 'publicKey': publicKey};
}
