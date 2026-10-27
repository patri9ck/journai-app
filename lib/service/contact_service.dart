// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Patrick Zwick

import '../model/contact/contact_request.dart';
import '../model/contact/contact_type.dart';
import '../model/contact/contact_verification.dart';
import '../model/result.dart';
import 'request_service.dart';

class ContactService {
  final RequestService _requestService;

  ContactService({required RequestService requestService}) : _requestService = requestService;

  Future<Result<void>> requestUpdate(ContactType type, String contact) async {
    final result = await _requestService.postAuthenticatedRequest(
      'update/${type.path}',
      ContactRequest(type: type, contact: contact).toJson(),
    );

    return voidResult(result);
  }

  Future<Result<void>> verifyUpdate(ContactType type, String contact, String code) async {
    final result = await _requestService.postAuthenticatedRequest(
      'update/verify/${type.path}',
      ContactVerification(type: type, contact: contact, code: code).toJson(),
    );

    return voidResult(result);
  }

  Future<Result<void>> deleteContact(ContactType type) async {
    final result = await _requestService.deleteAuthenticatedRequest('user/${type.path}');

    return voidResult(result);
  }
}
