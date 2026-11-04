// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Patrick Zwick

import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:journai_app/service/currency_service.dart';

void main() {
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  test('convert goes through the rates of the base currency', () {
    final service = CurrencyService();
    final rates = {'EUR': 1.0, 'USD': 1.1, 'JPY': 160.0};

    expect(service.convert(10, 'EUR', 'EUR', rates), 10);
    expect(service.convert(10, 'EUR', 'USD', rates), closeTo(11, 0.001));
    expect(service.convert(11, 'USD', 'EUR', rates), closeTo(10, 0.001));
    expect(service.convert(1, 'USD', 'JPY', rates), closeTo(160 / 1.1, 0.001));
  });

  test('unknown currencies are treated as the base', () {
    final service = CurrencyService();

    expect(service.convert(7, 'XXX', 'EUR', {'EUR': 1.0}), 7);
  });

  test('fetchRates puts the base first with rate 1 and caches the result', () async {
    final service = CurrencyService();

    final rates = await http.runWithClient(
      () => service.fetchRates('EUR'),
      () => MockClient((request) async {
        expect(request.url.toString(), 'https://api.frankfurter.app/latest?from=EUR');

        return http.Response(jsonEncode({'base': 'EUR', 'rates': {'USD': 1.1}}), 200);
      }),
    );

    expect(rates?.keys.first, 'EUR');
    expect(rates?['EUR'], 1.0);
    expect(rates?['USD'], 1.1);

    final cached = await service.getCachedRates('EUR');

    expect(cached?['USD'], 1.1);
    expect(await service.getCacheAge('EUR'), isNotNull);
  });

  test('a failed fetch returns null and keeps no cache', () async {
    final service = CurrencyService();

    final rates = await http.runWithClient(
      () => service.fetchRates('USD'),
      () => MockClient((request) async => http.Response('error', 500)),
    );

    expect(rates, isNull);
    expect(await service.getCachedRates('USD'), isNull);
    expect(await service.getCacheAge('USD'), isNull);
  });
}
