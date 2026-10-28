// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Patrick Zwick

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart';

import '../model/result.dart';
import '../util/auth_notifier.dart';
import '../util/http_timeout.dart';
import '../util/navigator_key.dart';
import '../util/storage.dart';
import 'services.dart';
import '../widget/page/start_page.dart';

class RequestService {
  final String _baseUrl;

  Future<Result<Map<String, dynamic>>>? _pendingRefresh;

  RequestService({required String baseUrl}) : _baseUrl = '${baseUrl}api/v1/';

  Future<Result<Map<String, dynamic>>> postRequest(
    String path,
    Map<String, dynamic> body,
  ) => _send('POST', path, body: body);

  Future<Result<Map<String, dynamic>>> postAuthenticatedRequest(
    String path,
    Map<String, dynamic> body,
  ) => _sendAuthenticated((accessToken) => _send('POST', path, body: body, accessToken: accessToken));

  Future<Result<Map<String, dynamic>>> getAuthenticatedRequest(String path) =>
      _sendAuthenticated((accessToken) => _send('GET', path, accessToken: accessToken));

  Future<Result<Map<String, dynamic>>> deleteAuthenticatedRequest(String path) =>
      _sendAuthenticated((accessToken) => _send('DELETE', path, accessToken: accessToken));

  Future<Result<Map<String, dynamic>>> putAuthenticatedRequest(String path, Map<String, dynamic> body) =>
      _sendAuthenticated((accessToken) => _send('PUT', path, body: body, accessToken: accessToken));

  Future<Result<Map<String, dynamic>>> _send(
    String method,
    String path, {
    Map<String, dynamic>? body,
    String? accessToken,
  }) async {
    final request = Request(method, Uri.parse('$_baseUrl$path'));

    if (accessToken != null) {
      request.headers['Authorization'] = 'Bearer $accessToken';
    }

    if (body != null) {
      request.headers['Content-Type'] = 'application/json';
      request.body = jsonEncode(body);
    }

    try {
      return _handleResponse(await request.send().then(Response.fromStream).timeout(httpTimeout));
    } on IOException catch (_) {
      return NetworkFailure();
    } on ClientException catch (_) {
      return NetworkFailure();
    } on TimeoutException catch (_) {
      return NetworkFailure();
    }
  }

  Result<Map<String, dynamic>> _handleResponse(Response response) {
    final isSuccess = response.statusCode >= 200 && response.statusCode < 300;

    try {
      if (isSuccess) {
        return Success(response.body.isEmpty ? {} : jsonDecode(response.body));
      }

      return ServerFailure.fromJson(jsonDecode(response.body), response.statusCode);
    } on FormatException catch (_) {
      if (isSuccess) {
        return Failure();
      }

      return ServerFailure(message: 'An error occurred.', key: 'internal-error', statusCode: response.statusCode);
    }
  }

  Future<Result<Map<String, dynamic>>> _sendAuthenticated(
    Future<Result<Map<String, dynamic>>> Function(String accessToken) request,
  ) async {
    final accessToken = await storage.read(key: 'accessToken');

    if (accessToken == null) {
      return Failure();
    }

    final result = await request(accessToken);

    if (result is! ServerFailure || (result as ServerFailure).statusCode != 401) {
      return result;
    }

    final latestAccessToken = await storage.read(key: 'accessToken');

    if (latestAccessToken != null && latestAccessToken != accessToken) {
      return request(latestAccessToken);
    }

    final refreshResult = await (_pendingRefresh ??= _refresh().whenComplete(() => _pendingRefresh = null));

    if (refreshResult is! Success<Map<String, dynamic>>) {
      return refreshResult;
    }

    return request(refreshResult.value!['accessToken'] as String);
  }

  Future<Result<Map<String, dynamic>>> _refresh() async {
    final refreshToken = await storage.read(key: 'refreshToken');

    if (refreshToken == null) {
      return Failure();
    }

    final result = await postRequest('refresh', {'refreshToken': refreshToken});

    if (result is ServerFailure && (result as ServerFailure).key == 'invalid-refresh-token') {
      await _resetToStartPage();

      return result;
    }

    if (result is! Success<Map<String, dynamic>>) {
      return result;
    }

    await storage.write(key: 'refreshToken', value: result.value!['refreshToken'] as String);
    await storage.write(key: 'accessToken', value: result.value!['accessToken'] as String);

    return result;
  }

  Future<void> _resetToStartPage() async {
    await clearAccount();

    isLoggedInNotifier.value = false;

    navigatorKey.currentState?.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const StartPage()),
      (_) => false,
    );
  }
}
