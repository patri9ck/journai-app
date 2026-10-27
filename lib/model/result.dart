// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Patrick Zwick

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../messages/app_localizations.dart';
import '../util/scaffold_messenger_key.dart';

sealed class Result<T> {}

class Failure<T> extends Result<T> {
  String localizedMessage([AppLocalizations? localizations]) {
    return localizations?.failure ?? 'An error occurred.';
  }

  void show([AppLocalizations? localizations]) {
    final messenger = scaffoldMessengerKey.currentState;

    if (messenger == null) {
      return;
    }

    messenger.removeCurrentSnackBar();

    messenger.showSnackBar(
      SnackBar(
        content: Text(
          localizedMessage(localizations),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

class NetworkFailure<T> extends Failure<T> {
  @override
  String localizedMessage([AppLocalizations? localizations]) {
    return localizations?.failureNoInternet ?? 'No internet connection.';
  }
}

class ServerFailure<T> extends Failure<T> {
  final String message;
  final String key;
  final int statusCode;
  final int? resetsAt;
  final int? imagesRemaining;
  final int? imagesAttempted;

  ServerFailure({
    required this.message,
    required this.key,
    required this.statusCode,
    this.resetsAt,
    this.imagesRemaining,
    this.imagesAttempted,
  });

  factory ServerFailure.fromJson(Map<String, dynamic> json, int statusCode) {
    return ServerFailure(
      message: json['message'] ?? "An internal error occurred.",
      key: json['key'] ?? "internal-error",
      statusCode: statusCode,
      resetsAt: json['resetsAt'] as int?,
      imagesRemaining: json['imagesRemaining'] as int?,
      imagesAttempted: json['imagesAttempted'] as int?,
    );
  }

  @override
  String localizedMessage([AppLocalizations? localizations]) {
    return _resolveMessage(localizations);
  }

  @override
  void show([AppLocalizations? localizations]) {
    final messenger = scaffoldMessengerKey.currentState;

    if (messenger == null) {
      return;
    }

    messenger.removeCurrentSnackBar();

    messenger.showSnackBar(
      SnackBar(
        content: Text(
          _resolveMessage(localizations),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  String _resolveMessage(AppLocalizations? localizations) {
    if (localizations != null && key == 'scan-limit-exceeded') {
      final remaining = imagesRemaining;
      final attempted = imagesAttempted;

      String? formattedResetDate() {
        if (resetsAt == null) {
          return null;
        }

        return DateFormat.yMd(localizations.localeName)
            .add_Hm()
            .format(DateTime.fromMillisecondsSinceEpoch(resetsAt! * 1000));
      }

      if (remaining != null && remaining > 0 && attempted != null) {
        final date = formattedResetDate();

        return date != null
            ? localizations.failureScanLimitPartialResetsAt(remaining, attempted, date)
            : localizations.failureScanLimitPartial(remaining, attempted);
      }

      final date = formattedResetDate();

      return date != null
          ? localizations.failureScanLimitResetsAt(date)
          : localizations.failureScanLimitAlltime;
    }

    return localizations != null
        ? (_localizations[key]?.call(localizations) ?? message)
        : message;
  }
}

final Map<String, String Function(AppLocalizations)> _localizations = {
  "missing-google-email-address": (appLocalizations) =>
      appLocalizations.failureMissingGoogleEmailAddress,
  "invalid-refresh-token": (appLocalizations) =>
      appLocalizations.failureInvalidRefreshToken,
  "logout-all-failed": (appLocalizations) =>
      appLocalizations.failureLogoutAllFailed,
  "user-already-registered": (appLocalizations) =>
      appLocalizations.failureUserAlreadyRegistered,
  "email-addresses-are-equal": (appLocalizations) =>
      appLocalizations.failureEmailAddressesAreEqual,
  "phone-numbers-are-equal": (appLocalizations) =>
      appLocalizations.failurePhoneNumbersAreEqual,
  "invalid-email-address": (appLocalizations) =>
      appLocalizations.failureInvalidEmailAddress,
  "invalid-phone-number": (appLocalizations) =>
      appLocalizations.failureInvalidPhoneNumber,
  "invalid-google-token": (appLocalizations) =>
      appLocalizations.failureInvalidGoogleToken,
  "email-address-not-existent": (appLocalizations) =>
      appLocalizations.failureEmailAddressNotExistent,
  "phone-number-not-existent": (appLocalizations) =>
      appLocalizations.failurePhoneNumberNotExistent,
  "google-account-not-existent": (appLocalizations) =>
      appLocalizations.failureGoogleAccountNotExistent,
  "user-not-existent": (appLocalizations) =>
      appLocalizations.failureUserNotExistent,
  "pending-verification": (appLocalizations) =>
      appLocalizations.failurePendingVerification,
  "invalid-verification-code": (appLocalizations) =>
      appLocalizations.failureInvalidVerificationCode,
  "maximum-verification-attempts-reached": (appLocalizations) =>
      appLocalizations.failureMaximumVerificationAttemptsReached,
  "limit-exceeded": (appLocalizations) => appLocalizations.failureLimitExceeded,
  "consent-required": (appLocalizations) => appLocalizations.failureConsentRequired,
  "scan-unavailable": (appLocalizations) => appLocalizations.failureScanUnavailable,
  "terms-not-accepted": (appLocalizations) => appLocalizations.failureTermsNotAccepted,
  "internal-error": (appLocalizations) => appLocalizations.failureInternalError,
  "encryption-already-set": (appLocalizations) => appLocalizations.failureEncryptionAlreadySet,
  "last-login-method": (appLocalizations) => appLocalizations.failureLastLoginMethod,
  "country-not-found": (appLocalizations) => appLocalizations.countryNoInformation,
  "entry-check-unavailable": (appLocalizations) => appLocalizations.failureEntryCheckUnavailable,
  "data-too-large": (appLocalizations) => appLocalizations.failureDataTooLarge,
  "invalid-apple-token": (appLocalizations) => appLocalizations.failureInvalidAppleToken,
  "apple-account-not-existent": (appLocalizations) => appLocalizations.failureAppleAccountNotExistent,
  "consent-already-given": (appLocalizations) => appLocalizations.failureConsentAlreadyGiven,
  "invalid-request": (appLocalizations) => appLocalizations.failureInvalidRequest,
  "subscription-unavailable": (appLocalizations) => appLocalizations.failureSubscriptionUnavailable,
  "verification-unavailable": (appLocalizations) => appLocalizations.failureVerificationUnavailable,
  "data-not-existent": (appLocalizations) => appLocalizations.failureDataNotExistent,
};

class Success<T> extends Result<T> {
  T? value;

  Success([this.value]);
}

Result<T> mapResult<T>(
  Result<Map<String, dynamic>> result,
  T Function(Map<String, dynamic>) fromJson,
) =>
    switch (result) {
      ServerFailure(:final message, :final key, :final statusCode, :final resetsAt, :final imagesRemaining, :final imagesAttempted) =>
        ServerFailure<T>(message: message, key: key, statusCode: statusCode, resetsAt: resetsAt, imagesRemaining: imagesRemaining, imagesAttempted: imagesAttempted),
      NetworkFailure() => NetworkFailure<T>(),
      Failure() => Failure<T>(),
      Success(:final value) => Success<T>(fromJson(value!)),
    };

Result<void> voidResult(Result<Map<String, dynamic>> result) =>
    switch (result) {
      ServerFailure(:final message, :final key, :final statusCode, :final resetsAt, :final imagesRemaining, :final imagesAttempted) =>
        ServerFailure<void>(message: message, key: key, statusCode: statusCode, resetsAt: resetsAt, imagesRemaining: imagesRemaining, imagesAttempted: imagesAttempted),
      NetworkFailure() => NetworkFailure<void>(),
      Failure() => Failure<void>(),
      Success() => Success<void>(),
    };
