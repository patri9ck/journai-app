// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Patrick Zwick

import 'dart:io';

import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import '../util/access_token.dart';
import '../util/storage.dart';
import 'request_service.dart';

class SubscriptionService {
  final String _googleApiKey;
  final String _appleApiKey;
  final RequestService _requestService;

  bool _initialized = false;

  SubscriptionService({
    required String googleApiKey,
    required String appleApiKey,
    required RequestService requestService,
  }) : _googleApiKey = googleApiKey,
       _appleApiKey = appleApiKey,
       _requestService = requestService;

  Future<void> connect() async {
    final apiKey = Platform.isAndroid ? _googleApiKey : _appleApiKey;
    final userId = userIdFromAccessToken(await storage.read(key: 'accessToken'));

    if (apiKey.isEmpty || userId == null) {
      return;
    }

    try {
      if (_initialized) {
        await Purchases.logIn(userId);
      } else {
        await Purchases.configure(PurchasesConfiguration(apiKey)..appUserID = userId);
        _initialized = true;
      }
    } on PlatformException {
      return;
    }
  }

  Future<void> _syncTier() async {
    await _requestService.postAuthenticatedRequest('subscription/sync', {});
  }

  Future<Offerings?> getOfferings() async {
    if (!_initialized) {
      return null;
    }

    try {
      return await Purchases.getOfferings();
    } catch (_) {
      return null;
    }
  }

  Future<bool> purchase(Package package) async {
    if (!_initialized) {
      return false;
    }

    try {
      await Purchases.purchase(PurchaseParams.package(package));
      await _syncTier();

      return true;
    } on PlatformException catch (exception) {
      if (PurchasesErrorHelper.getErrorCode(exception) == PurchasesErrorCode.purchaseCancelledError) {
        return false;
      }

      rethrow;
    }
  }

  Future<bool> restore() async {
    if (!_initialized) {
      return false;
    }

    try {
      final info = await Purchases.restorePurchases();
      await _syncTier();

      return info.entitlements.active.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<String> managementUrl() async {
    final managementUrl = (await getCustomerInfo())?.managementURL;

    if (managementUrl != null) {
      return managementUrl;
    }

    if (Platform.isIOS) {
      return 'https://apps.apple.com/account/subscriptions';
    }

    return 'https://play.google.com/store/account/subscriptions?package=xyz.journai.app';
  }

  Future<CustomerInfo?> getCustomerInfo() async {
    if (!_initialized) {
      return null;
    }

    try {
      return await Purchases.getCustomerInfo();
    } catch (_) {
      return null;
    }
  }
}
