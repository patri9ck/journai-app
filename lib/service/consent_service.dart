// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Patrick Zwick

import '../model/consent_type.dart';
import '../model/result.dart';
import 'request_service.dart';

class ConsentService {
  final RequestService _requestService;

  ConsentService({required RequestService requestService}) : _requestService = requestService;

  Future<bool> hasConsent(ConsentType type) async {
    final result = await _requestService.getAuthenticatedRequest('user/consent/${type.apiName}');

    if (result is! Success<Map<String, dynamic>>) {
      return false;
    }

    return result.value?['hasConsent'] as bool? ?? false;
  }

  Future<Result<void>> giveConsent(ConsentType type) async {
    final result = await _requestService.postAuthenticatedRequest('user/consent/${type.apiName}', {});

    return voidResult(result);
  }

  Future<Result<void>> revokeConsent(ConsentType type) async {
    final result = await _requestService.deleteAuthenticatedRequest('user/consent/${type.apiName}');

    return voidResult(result);
  }
}
