// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Patrick Zwick

import 'dart:convert';
import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:journai_app/model/result.dart';
import 'package:journai_app/service/request_service.dart';
import 'package:journai_app/util/storage.dart';

void main() {
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  RequestService service() => RequestService(baseUrl: 'http://test/');

  test('a JSON object response becomes a success and the body is sent as JSON', () async {
    http.BaseRequest? captured;

    final result = await http.runWithClient(
      () => service().postRequest('thing', {'a': 1}),
      () => MockClient((request) async {
        captured = request;

        return http.Response(jsonEncode({'ok': true}), 200);
      }),
    );

    expect(result, isA<Success<Map<String, dynamic>>>());
    expect((result as Success).value, {'ok': true});
    expect(captured!.method, 'POST');
    expect(captured!.url.toString(), 'http://test/api/v1/thing');
    expect(captured!.headers['Content-Type'], 'application/json');
    expect((captured! as http.Request).body, '{"a":1}');
  });

  test('an empty success response becomes an empty map', () async {
    await storage.write(key: 'accessToken', value: 'token');

    final result = await http.runWithClient(
      () => service().getAuthenticatedRequest('data'),
      () => MockClient((request) async => http.Response('', 204)),
    );

    expect(result, isA<Success<Map<String, dynamic>>>().having((success) => success.value, 'value', {}));
  });

  test('a non-object success response is a failure instead of crashing', () async {
    final result = await http.runWithClient(
      () => service().postRequest('x', {}),
      () => MockClient((request) async => http.Response('[1, 2]', 200)),
    );

    expect(result, isA<Failure<Map<String, dynamic>>>());
    expect(result, isNot(isA<ServerFailure>()));
  });

  test('an error response keeps the server message and key', () async {
    final result = await http.runWithClient(
      () => service().postRequest('x', {}),
      () => MockClient((request) async => http.Response(
            jsonEncode({'message': 'Nope.', 'key': 'invalid-request', 'resetsAt': 123}),
            400,
          )),
    );

    expect(result, isA<ServerFailure<Map<String, dynamic>>>()
        .having((failure) => failure.key, 'key', 'invalid-request')
        .having((failure) => failure.message, 'message', 'Nope.')
        .having((failure) => failure.statusCode, 'statusCode', 400)
        .having((failure) => failure.resetsAt, 'resetsAt', 123));
  });

  test('a non-JSON error response becomes a generic server failure', () async {
    final result = await http.runWithClient(
      () => service().postRequest('x', {}),
      () => MockClient((request) async => http.Response('<html>bad gateway</html>', 502)),
    );

    expect(result, isA<ServerFailure<Map<String, dynamic>>>()
        .having((failure) => failure.key, 'key', 'internal-error')
        .having((failure) => failure.statusCode, 'statusCode', 502));
  });

  test('a network error becomes a network failure', () async {
    final result = await http.runWithClient(
      () => service().postRequest('x', {}),
      () => MockClient((request) async => throw const SocketException('no route')),
    );

    expect(result, isA<NetworkFailure<Map<String, dynamic>>>());
  });

  test('an authenticated request without a token fails locally', () async {
    final result = await service().getAuthenticatedRequest('data');

    expect(result, isA<Failure<Map<String, dynamic>>>());
    expect(result, isNot(isA<ServerFailure>()));
  });

  test('a 401 triggers one refresh and retries with the new token', () async {
    await storage.write(key: 'accessToken', value: 'old');
    await storage.write(key: 'refreshToken', value: 'refresh');

    var refreshCalls = 0;
    var dataCalls = 0;
    final shared = service();

    final results = await http.runWithClient(
      () => Future.wait([
        shared.getAuthenticatedRequest('data'),
        shared.getAuthenticatedRequest('data'),
      ]),
      () => MockClient((request) async {
        if (request.url.path.endsWith('/refresh')) {
          refreshCalls++;

          return http.Response(jsonEncode({'accessToken': 'new', 'refreshToken': 'new-refresh'}), 200);
        }

        dataCalls++;

        if (request.headers['Authorization'] == 'Bearer old') {
          return http.Response('', 401);
        }

        return http.Response(jsonEncode({'data': []}), 200);
      }),
    );

    expect(results.every((result) => result is Success<Map<String, dynamic>>), isTrue);
    expect(refreshCalls, 1);
    expect(dataCalls, 4);
    expect(await storage.read(key: 'accessToken'), 'new');
    expect(await storage.read(key: 'refreshToken'), 'new-refresh');
  });

  test('a failed refresh propagates the failure', () async {
    await storage.write(key: 'accessToken', value: 'old');
    await storage.write(key: 'refreshToken', value: 'refresh');

    final result = await http.runWithClient(
      () => service().getAuthenticatedRequest('data'),
      () => MockClient((request) async {
        if (request.url.path.endsWith('/refresh')) {
          return http.Response(jsonEncode({'message': 'offline', 'key': 'internal-error'}), 500);
        }

        return http.Response('', 401);
      }),
    );

    expect(result, isA<ServerFailure<Map<String, dynamic>>>().having((failure) => failure.statusCode, 'statusCode', 500));
  });
}
