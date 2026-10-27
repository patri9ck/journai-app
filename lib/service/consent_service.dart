// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Patrick Zwick

import '../model/result.dart';
import 'request_service.dart';

class ConsentService {
  final RequestService _requestService;

  ConsentService({required RequestService requestService})
    : _requestService = requestService;

  Future<bool> hasHealthDataScanConsent() async {
    final result = await _requestService.getAuthenticatedRequest(
      'user/consent/HEALTH_DATA_SCAN',
    );

    if (result is! Success<Map<String, dynamic>>) {
      return false;
    }

    return result.value?['hasConsent'] as bool? ?? false;
  }

  Future<Result<void>> giveHealthDataScanConsent() async {
    final result = await _requestService.postAuthenticatedRequest(
      'user/consent/HEALTH_DATA_SCAN',
      {},
    );

    return voidResult(result);
  }

  Future<bool> hasDocumentScanConsent() async {
    final result = await _requestService.getAuthenticatedRequest(
      'user/consent/DOCUMENT_SCAN',
    );

    if (result is! Success<Map<String, dynamic>>) {
      return false;
    }

    return result.value?['hasConsent'] as bool? ?? false;
  }

  Future<Result<void>> giveDocumentScanConsent() async {
    final result = await _requestService.postAuthenticatedRequest(
      'user/consent/DOCUMENT_SCAN',
      {},
    );

    return voidResult(result);
  }

  Future<Result<void>> revokeHealthDataScanConsent() async {
    final result = await _requestService.deleteAuthenticatedRequest(
      'user/consent/HEALTH_DATA_SCAN',
    );

    return voidResult(result);
  }

  Future<Result<void>> revokeDocumentScanConsent() async {
    final result = await _requestService.deleteAuthenticatedRequest(
      'user/consent/DOCUMENT_SCAN',
    );

    return voidResult(result);
  }
}
