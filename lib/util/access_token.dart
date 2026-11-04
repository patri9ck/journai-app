// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Patrick Zwick

import 'dart:convert';

String? userIdFromAccessToken(String? accessToken) {
  final parts = accessToken?.split('.');

  if (parts == null || parts.length != 3) {
    return null;
  }

  try {
    final payload = jsonDecode(utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))));

    if (payload is! Map<String, dynamic>) {
      return null;
    }

    return payload['id']?.toString();
  } on FormatException {
    return null;
  }
}
