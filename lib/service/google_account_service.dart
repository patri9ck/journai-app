// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Patrick Zwick

import 'package:google_sign_in/google_sign_in.dart';

class GoogleAccountService {
  final String _serverClientId;

  GoogleAccountService({required String serverClientId}) : _serverClientId = serverClientId;

  Future<void> initialize() async {
    await GoogleSignIn.instance.initialize(serverClientId: _serverClientId);
  }

  Future<String?> getIdToken() async {
    try {
      final account = await GoogleSignIn.instance.authenticate();

      return account.authentication.idToken;
    } on GoogleSignInException {
      return null;
    }
  }
}
