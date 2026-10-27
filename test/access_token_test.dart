// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Patrick Zwick

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:journai_app/util/access_token.dart';

void main() {
  String token(Object payload) =>
      'header.${base64Url.encode(utf8.encode(jsonEncode(payload))).replaceAll('=', '')}.signature';

  test('the account id is read from the token payload', () {
    expect(userIdFromAccessToken(token({'id': 42, 'admin': false})), '42');
  });

  test('broken or missing tokens give no account id', () {
    expect(userIdFromAccessToken(null), isNull);
    expect(userIdFromAccessToken('screenshot-demo'), isNull);
    expect(userIdFromAccessToken('a.not-base64!.c'), isNull);
    expect(userIdFromAccessToken(token(['not', 'an', 'object'])), isNull);
    expect(userIdFromAccessToken(token({'admin': true})), isNull);
  });
}
