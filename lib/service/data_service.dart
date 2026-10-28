// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Patrick Zwick

import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography_plus/cryptography_plus.dart';

import '../model/data.dart';
import '../model/result.dart';
import '../util/cache.dart';
import '../util/profile_notifier.dart';
import '../util/storage.dart';
import 'cryptography_service.dart';
import 'request_service.dart';

class DataService {
  final RequestService _requestService;
  final CryptographyService _cryptographyService;

  DataService({
    required RequestService requestService,
    required CryptographyService cryptographyService,
  }) : _requestService = requestService,
       _cryptographyService = cryptographyService;

  Future<Result<List<Map<String, dynamic>>>> scanImages(
    String category,
    List<Uint8List> imageBytesList,
  ) async {
    final serverPublicKey = await storage.read(key: 'serverPublicKey');
    final salt = await storage.read(key: 'transferSalt');

    if (serverPublicKey == null || salt == null) {
      return Failure<List<Map<String, dynamic>>>();
    }

    final transferKey =
        await _cryptographyService.deriveTransferKey(serverPublicKey, salt);

    final encryptedImages = await Future.wait(
      imageBytesList.map(
        (bytes) => _cryptographyService.encryptForTransfer(bytes, transferKey),
      ),
    );

    final result = await _requestService.postAuthenticatedRequest(
      'data/$category/scan',
      {'images': encryptedImages},
    );

    if (result is! Success<Map<String, dynamic>>) {
      return _toTypedFailure<List<Map<String, dynamic>>>(result as Failure);
    }

    final encryptedResult = result.value?['data'] as String?;

    if (encryptedResult == null) {
      return Failure<List<Map<String, dynamic>>>();
    }

    try {
      final decryptedBytes = await _cryptographyService.decryptFromTransfer(
        encryptedResult,
        transferKey,
      );

      final jsonList = jsonDecode(utf8.decode(decryptedBytes)) as List;

      return Success(
        jsonList.map((item) => Map<String, dynamic>.from(item as Map)).toList(),
      );
    } on SecretBoxAuthenticationError {
      return Failure<List<Map<String, dynamic>>>();
    } on FormatException {
      return Failure<List<Map<String, dynamic>>>();
    } on TypeError {
      return Failure<List<Map<String, dynamic>>>();
    }
  }

  Future<Result<void>> saveData(Data data) async {
    final payload = jsonEncode(_withSelectedProfile(data).toJson());
    final encryptedData = await _cryptographyService.encryptData(payload);

    final result = await _requestService.postAuthenticatedRequest('data', {
      'feature': data.feature,
      'data': encryptedData,
    });

    return voidResult(result);
  }

  Future<List<Data>> getCachedData([List<String>? features]) async {
    return _forSelectedProfile(await _readCachedData(features), features);
  }

  Future<List<Data>> getCachedDataOfAllProfiles() async {
    final entries = await _readCachedData();

    return entries.where((entry) => entry.feature != 'PROFILE').toList();
  }

  Future<Result<void>> deleteProfile(int profileId) async {
    final refreshResult = await getData();

    if (refreshResult is Failure<List<Data>>) {
      return refreshResult is NetworkFailure<List<Data>> ? NetworkFailure<void>() : Failure<void>();
    }

    final entries = await _readCachedData();

    for (final entry in entries.where((entry) => entry.profileId == profileId)) {
      final result = await deleteData(entry.id!);

      if (result is Failure<void>) {
        return result;
      }
    }

    return deleteData(profileId);
  }

  Future<List<Data>> _readCachedData([List<String>? features]) async {
    return _decrypt(await readListCache('cache_data') ?? [], features);
  }

  Future<List<Data>> _decrypt(List<Map<String, dynamic>> rawItems, List<String>? features) async {
    final entries = <Data>[];
    final dataKey = await _cryptographyService.readDataKey();

    if (dataKey == null) {
      return entries;
    }

    for (final map in rawItems) {
      final serverFeature = (map['feature'] ?? map['category']) as String? ?? '';

      if (features != null && !features.contains(serverFeature)) {
        continue;
      }

      try {
        final decrypted = await _cryptographyService.decryptData(map['data'] as String, dataKey);
        final dataJson = jsonDecode(decrypted) as Map<String, dynamic>;

        entries.add(
          Data.fromJson({
            ...dataJson,
            'id': map['id'] as int,
            'feature': dataJson['feature'] ?? dataJson['category'] ?? serverFeature,
          }),
        );
      } catch (_) {
        continue;
      }
    }

    return entries;
  }

  Future<Result<List<Data>>> getData([List<String>? features]) async {
    final result = await _requestService.getAuthenticatedRequest('data');

    List<Map<String, dynamic>> rawItems;

    if (result is Success<Map<String, dynamic>>) {
      rawItems = ((result.value?['data'] as List?) ?? [])
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList();

      await saveListCache('cache_data', rawItems);
    } else {
      final cached = await readListCache('cache_data');

      if (cached != null) {
        rawItems = cached;
      } else {
        return _toTypedFailure<List<Data>>(result as Failure);
      }
    }

    final entries = await _decrypt(rawItems, features);

    return Success(_forSelectedProfile(entries, features));
  }

  List<Data> _forSelectedProfile(List<Data> entries, List<String>? features) {
    final profileId = selectedProfileNotifier.value;

    return entries.where((entry) {
      if (entry.feature == 'PROFILE') {
        return features?.contains('PROFILE') ?? false;
      }

      return entry.profileId == profileId;
    }).toList();
  }

  Data _withSelectedProfile(Data data) {
    if (data.feature == 'PROFILE') {
      return data;
    }

    return Data(id: data.id, feature: data.feature, fields: data.fields, profileId: selectedProfileNotifier.value);
  }

  Future<Result<void>> updateData(int dataId, Data data) async {
    final payload = jsonEncode(_withSelectedProfile(data).toJson());
    final encryptedData = await _cryptographyService.encryptData(payload);

    final result = await _requestService.putAuthenticatedRequest(
      'data/$dataId',
      {'data': encryptedData},
    );

    return voidResult(result);
  }

  Future<Result<void>> deleteData(int dataId) async {
    final result = await _requestService.deleteAuthenticatedRequest('data/$dataId');

    if (result is Success) {
      final cached = await readListCache('cache_data');

      if (cached != null) {
        await saveListCache('cache_data', cached.where((item) => item['id'] != dataId).toList());
      }
    }

    return voidResult(result);
  }

  Future<Result<void>> deleteAllData() async {
    final result = await _requestService.deleteAuthenticatedRequest('data');

    if (result is Success) {
      await storage.delete(key: 'cache_data');
    }

    return voidResult(result);
  }

  Result<T> _toTypedFailure<T>(Failure failure) {
    if (failure is NetworkFailure) {
      return NetworkFailure<T>();
    }

    if (failure is ServerFailure) {
      return ServerFailure<T>(
        message: failure.message,
        key: failure.key,
        statusCode: failure.statusCode,
        resetsAt: failure.resetsAt,
        imagesRemaining: failure.imagesRemaining,
        imagesAttempted: failure.imagesAttempted,
      );
    }

    return Failure<T>();
  }
}
