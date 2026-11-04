// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Patrick Zwick

import 'package:flutter_test/flutter_test.dart';
import 'package:journai_app/model/result.dart';

void main() {
  test('mapResult parses successes and preserves failures', () {
    final success = mapResult(Success({'n': 5}), (json) => json['n'] as int);

    expect(success, isA<Success<int>>().having((result) => result.value, 'value', 5));

    final serverFailure = ServerFailure<Map<String, dynamic>>(
      message: 'm',
      key: 'k',
      statusCode: 402,
      resetsAt: 1,
      imagesRemaining: 2,
      imagesAttempted: 3,
    );

    final mapped = mapResult<int>(serverFailure, (json) => 0);

    expect(mapped, isA<ServerFailure<int>>()
        .having((failure) => failure.key, 'key', 'k')
        .having((failure) => failure.statusCode, 'statusCode', 402)
        .having((failure) => failure.resetsAt, 'resetsAt', 1)
        .having((failure) => failure.imagesRemaining, 'imagesRemaining', 2)
        .having((failure) => failure.imagesAttempted, 'imagesAttempted', 3));

    expect(mapResult<int>(NetworkFailure(), (json) => 0), isA<NetworkFailure<int>>());
    expect(mapResult<int>(Failure(), (json) => 0), isA<Failure<int>>());
    expect(mapResult<int>(Failure(), (json) => 0).runtimeType, Failure<int>);
  });

  test('voidResult keeps the failure type and details', () {
    expect(voidResult(Success({})), isA<Success<void>>());
    expect(voidResult(NetworkFailure()), isA<NetworkFailure<void>>());

    final failure = voidResult(ServerFailure(message: 'm', key: 'limit-exceeded', statusCode: 402));

    expect(failure, isA<ServerFailure<void>>().having((result) => result.key, 'key', 'limit-exceeded'));
  });

  test('ServerFailure.fromJson tolerates non-object bodies', () {
    final fromNull = ServerFailure.fromJson(null, 500);

    expect(fromNull.key, 'internal-error');
    expect(fromNull.statusCode, 500);

    final fromList = ServerFailure.fromJson([1, 2], 400);

    expect(fromList.key, 'internal-error');
    expect(fromList.message, 'An internal error occurred.');
  });
}
