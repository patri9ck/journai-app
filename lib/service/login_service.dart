// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Patrick Zwick

import '../model/login/apple_login.dart';
import '../model/registration/apple_registration.dart';
import '../model/login/email_login.dart';
import '../model/login/email_login_verification.dart';
import '../model/registration/email_registration.dart';
import '../model/registration/email_registration_verification.dart';
import '../model/login/google_login.dart';
import '../model/registration/google_registration.dart';
import '../model/login/login.dart';
import '../model/login/phone_login.dart';
import '../model/login/phone_login_verification.dart';
import '../model/registration/phone_registration.dart';
import '../model/registration/phone_registration_verification.dart';
import '../model/result.dart';
import '../util/storage.dart';
import 'cryptography_service.dart';
import 'request_service.dart';

class LoginService {
  final RequestService _requestService;
  final CryptographyService _cryptographyService;

  LoginService({
    required RequestService requestService,
    required CryptographyService cryptographyService,
  }) : _requestService = requestService,
       _cryptographyService = cryptographyService;

  Future<Result<void>> requestEmailLogin(String emailAddress) async {
    final result = await _requestService.postRequest(
      'login/email',
      EmailLogin(emailAddress: emailAddress).toJson(),
    );

    return voidResult(result);
  }

  Future<Result<void>> requestEmailRegistration(String emailAddress, String locale) async {
    final result = await _requestService.postRequest(
      'register/email',
      EmailRegistration(emailAddress: emailAddress, locale: locale).toJson(),
    );

    return voidResult(result);
  }

  Future<Result<Login>> verifyEmailLogin(String emailAddress, String code) async {
    final publicKey = await _cryptographyService.generateKeyPair();

    final result = await _requestService.postRequest(
      'login/verify/email',
      EmailLoginVerification(emailAddress: emailAddress, code: code, publicKey: publicKey).toJson(),
    );

    return _processLoginResult(result);
  }

  Future<Result<Login>> verifyEmailRegistration(
    String emailAddress,
    String code,
    bool termsAccepted,
  ) async {
    final publicKey = await _cryptographyService.generateKeyPair();

    final result = await _requestService.postRequest(
      'register/verify/email',
      EmailRegistrationVerification(
        emailAddress: emailAddress,
        code: code,
        publicKey: publicKey,
        termsAccepted: termsAccepted,
      ).toJson(),
    );

    return _processLoginResult(result);
  }

  Future<Result<void>> requestPhoneLogin(String phoneNumber) async {
    final result = await _requestService.postRequest(
      'login/phone',
      PhoneLogin(phoneNumber: phoneNumber).toJson(),
    );

    return voidResult(result);
  }

  Future<Result<void>> requestPhoneRegistration(String phoneNumber, String locale) async {
    final result = await _requestService.postRequest(
      'register/phone',
      PhoneRegistration(phoneNumber: phoneNumber, locale: locale).toJson(),
    );

    return voidResult(result);
  }

  Future<Result<Login>> verifyPhoneLogin(String phoneNumber, String code) async {
    final publicKey = await _cryptographyService.generateKeyPair();

    final result = await _requestService.postRequest(
      'login/verify/phone',
      PhoneLoginVerification(phoneNumber: phoneNumber, code: code, publicKey: publicKey).toJson(),
    );

    return _processLoginResult(result);
  }

  Future<Result<Login>> verifyPhoneRegistration(
    String phoneNumber,
    String code,
    bool termsAccepted,
  ) async {
    final publicKey = await _cryptographyService.generateKeyPair();

    final result = await _requestService.postRequest(
      'register/verify/phone',
      PhoneRegistrationVerification(
        phoneNumber: phoneNumber,
        code: code,
        publicKey: publicKey,
        termsAccepted: termsAccepted,
      ).toJson(),
    );

    return _processLoginResult(result);
  }

  Future<Result<Login>> loginWithApple(String token) async {
    final publicKey = await _cryptographyService.generateKeyPair();

    final result = await _requestService.postRequest(
      'login/apple',
      AppleLogin(token: token, publicKey: publicKey).toJson(),
    );

    return _processLoginResult(result);
  }

  Future<Result<Login>> loginWithGoogle(String token) async {
    final publicKey = await _cryptographyService.generateKeyPair();

    final result = await _requestService.postRequest(
      'login/google',
      GoogleLogin(token: token, publicKey: publicKey).toJson(),
    );

    return _processLoginResult(result);
  }

  Future<Result<Login>> registerWithApple(String token, String locale, bool termsAccepted) async {
    final publicKey = await _cryptographyService.generateKeyPair();

    final result = await _requestService.postRequest(
      'register/apple',
      AppleRegistration(token: token, locale: locale, publicKey: publicKey, termsAccepted: termsAccepted).toJson(),
    );

    return _processLoginResult(result);
  }

  Future<Result<Login>> registerWithGoogle(String token, String locale, bool termsAccepted) async {
    final publicKey = await _cryptographyService.generateKeyPair();

    final result = await _requestService.postRequest(
      'register/google',
      GoogleRegistration(token: token, locale: locale, publicKey: publicKey, termsAccepted: termsAccepted).toJson(),
    );

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
