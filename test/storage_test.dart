// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Patrick Zwick

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:journai_app/util/storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');

  void mockStorage(Future<Object?> Function(MethodCall call) handler) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, handler);
  }

  tearDown(() => mockStorage((_) async => null));

  test('a read that fails briefly is retried', () async {
    var calls = 0;

    mockStorage((call) async {
      calls++;

      if (calls == 1) {
        throw PlatformException(code: 'keystore');
      }

      return 'refresh-token';
    });

    expect(await storage.read(key: 'refreshToken'), 'refresh-token');
    expect(calls, 2);
  });

  test('a read that keeps failing returns null and never deletes anything', () async {
    final methods = <String>[];

    mockStorage((call) async {
      methods.add(call.method);

      throw PlatformException(code: 'keystore');
    });

    expect(await storage.read(key: 'failingKey'), isNull);
    expect(methods, everyElement('read'));
  });

  test('a value is read from the platform only once', () async {
    var calls = 0;

    mockStorage((call) async {
      calls++;

      return 'metric';
    });

    expect(await storage.read(key: 'cachedKey'), 'metric');
    expect(await storage.read(key: 'cachedKey'), 'metric');
    expect(calls, 1);

    await storage.write(key: 'cachedKey', value: 'imperial');

    expect(await storage.read(key: 'cachedKey'), 'imperial');
    expect(calls, 2);
  });

  test('the storage is configured not to reset itself on errors', () async {
    Map<Object?, Object?>? options;

    mockStorage((call) async {
      options = (call.arguments as Map)['options'] as Map<Object?, Object?>;

      return null;
    });

    await storage.read(key: 'optionsKey');

    expect(options?['resetOnError'], 'false');
  });
}
