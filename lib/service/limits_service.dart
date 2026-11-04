// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Patrick Zwick

import '../model/limits.dart';
import '../model/result.dart';
import '../util/cache.dart';
import 'request_service.dart';

class LimitsService {
  final RequestService _requestService;

  LimitsService({required RequestService requestService})
    : _requestService = requestService;

  Future<Limits> getCachedLimits() async {
    final cached = await readObjectCache('cache_limits');

    if (cached != null) {
      return Limits.fromJson(cached);
    }

    return Limits.unlimited;
  }

  Future<Limits> getLimits() async {
    final result = await _requestService.getAuthenticatedRequest('user/limits');

    if (result is Success<Map<String, dynamic>>) {
      final limits = Limits.fromJson(result.value!);
      await saveObjectCache('cache_limits', result.value!);
      return limits;
    }

    final cached = await readObjectCache('cache_limits');

    if (cached != null) {
      return Limits.fromJson(cached);
    }

    return Limits.unlimited;
  }
}
