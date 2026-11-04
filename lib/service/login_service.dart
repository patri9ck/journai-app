// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Patrick Zwick

import '../model/auth_mode.dart';
import '../model/contact/contact_login_verification.dart';
import '../model/contact/contact_registration.dart';
import '../model/contact/contact_registration_verification.dart';
import '../model/contact/contact_request.dart';
import '../model/contact/contact_type.dart';
import '../model/login/external_account_login.dart';
import '../model/login/external_account_registration.dart';
import '../model/login/external_account_type.dart';
import '../model/login/login.dart';
import '../model/result.dart';
import '../util/storage.dart';
import 'apple_account_service.dart';
import 'cryptography_service.dart';
import 'google_account_service.dart';
import 'request_service.dart';

class LoginService {
  final RequestService _requestService;
  final CryptographyService _cryptographyService;
  final GoogleAccountService _googleAccountService;
  final AppleAccountService _appleAccountService;

  LoginService({
    required RequestService requestService,
    required CryptographyService cryptographyService,
    required GoogleAccountService googleAccountService,
    required AppleAccountService appleAccountService,
  }) : _requestService = requestService,
       _cryptographyService = cryptographyService,
       _googleAccountService = googleAccountService,
       _appleAccountService = appleAccountService;

  Future<Result<void>> requestLogin(ContactType type, String contact) async {
    final result = await _requestService.postRequest(
      'login/${type.path}',
      ContactRequest(type: type, contact: contact).toJson(),
    );

    return voidResult(result);
  }

  Future<Result<void>> requestRegistration(ContactType type, String contact, String locale) async {
    final result = await _requestService.postRequest(
      'register/${type.path}',
      ContactRegistration(type: type, contact: contact, locale: locale).toJson(),
    );

    return voidResult(result);
  }

  Future<Result<Login>> verifyLogin(ContactType type, String contact, String code) async {
    final publicKey = await _cryptographyService.generateKeyPair();

    final result = await _requestService.postRequest(
      'login/verify/${type.path}',
      ContactLoginVerification(type: type, contact: contact, code: code, publicKey: publicKey).toJson(),
    );

    return _processLoginResult(result);
  }

  Future<Result<Login>> verifyRegistration(ContactType type, String contact, String code, bool termsAccepted) async {
    final publicKey = await _cryptographyService.generateKeyPair();

    final result = await _requestService.postRequest(
      'register/verify/${type.path}',
      ContactRegistrationVerification(
        type: type,
        contact: contact,
        code: code,
        publicKey: publicKey,
        termsAccepted: termsAccepted,
      ).toJson(),
    );

    return _processLoginResult(result);
  }

  Future<Result<Login>?> authenticateWithExternalAccount(
    ExternalAccountType type,
    AuthMode mode,
    String locale,
    bool termsAccepted,
  ) async {
    final token = switch (type) {
      ExternalAccountType.google => await _googleAccountService.getIdToken(),
      ExternalAccountType.apple => await _appleAccountService.getIdentityToken(),
    };

    if (token == null) {
      return null;
    }

    final publicKey = await _cryptographyService.generateKeyPair();

    final result = switch (mode) {
      AuthMode.login => await _requestService.postRequest(
        'login/${type.path}',
        ExternalAccountLogin(token: token, publicKey: publicKey).toJson(),
      ),
      AuthMode.register => await _requestService.postRequest(
        'register/${type.path}',
        ExternalAccountRegistration(
          token: token,
          locale: locale,
          publicKey: publicKey,
          termsAccepted: termsAccepted,
        ).toJson(),
      ),
    };

    return _processLoginResult(result);
  }

  Future<Result<Login>> _processLoginResult(Result<Map<String, dynamic>> result) async {
    final loginResult = mapResult(result, Login.fromJson);

    if (loginResult is Success<Login>) {
      final login = loginResult.value!;

      await storage.write(key: 'accessToken', value: login.accessToken);
      await storage.write(key: 'refreshToken', value: login.refreshToken);
      await storage.write(key: 'serverPublicKey', value: login.publicKey);
      await storage.write(key: 'transferSalt', value: login.salt);

      if (login.encryptedDataKey != null) {
        await storage.write(key: 'encryptedDataKey', value: login.encryptedDataKey!);
      }

      if (login.deletionCancelled) {
        await storage.write(key: 'deletion_cancelled_notification', value: 'true');
      }
    }

    return loginResult;
  }
}
