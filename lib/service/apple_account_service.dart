// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Patrick Zwick

import 'package:sign_in_with_apple/sign_in_with_apple.dart';

class AppleAccountService {
  Future<String?> getIdentityToken() async {
    try {
      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: [AppleIDAuthorizationScopes.email],
      );

      return credential.identityToken;
    } on SignInWithAppleException {
      return null;
    }
  }
}
