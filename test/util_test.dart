// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Patrick Zwick

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:journai_app/util/cache.dart';
import 'package:journai_app/util/document_date.dart';
import 'package:journai_app/util/storage.dart';

void main() {
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  group('document dates', () {
    test('parses German and ISO dates', () {
      expect(parseDocumentDate('5.3.2026'), DateTime(2026, 3, 5));
      expect(parseDocumentDate('05.03.2026'), DateTime(2026, 3, 5));
      expect(parseDocumentDate('2026-03-05'), DateTime(2026, 3, 5));
    });

    test('rejects empty and invalid input', () {
      expect(parseDocumentDate(null), isNull);
      expect(parseDocumentDate('  '), isNull);
      expect(parseDocumentDate('tomorrow'), isNull);
    });

    test('formats as dd.MM.yyyy', () {
      expect(formatDocumentDate(DateTime(2026, 3, 5)), '05.03.2026');
    });
  });

  group('cache', () {
    test('list cache round-trips and survives broken values', () async {
      expect(await readListCache('missing'), isNull);

      await saveListCache('list', [
        {'a': 1},
        {'b': 'x'},
      ]);

      expect(await readListCache('list'), [
        {'a': 1},
        {'b': 'x'},
      ]);

      await storage.write(key: 'broken', value: 'not json');
      expect(await readListCache('broken'), isNull);

      await storage.write(key: 'broken2', value: '{"not":"a list"}');
      expect(await readListCache('broken2'), isNull);
    });

    test('object cache round-trips and survives broken values', () async {
      expect(await readObjectCache('missing'), isNull);

      await saveObjectCache('obj', {'x': [1, 2]});

      expect(await readObjectCache('obj'), {'x': [1, 2]});

      await storage.write(key: 'broken', value: '[1]');
      expect(await readObjectCache('broken'), isNull);
    });
  });

  group('storage', () {
    test('written values are cached in memory and survive failing reads', () async {
      await storage.write(key: 'k', value: 'v');

      expect(await storage.read(key: 'k'), 'v');

      await storage.delete(key: 'k');

      expect(await storage.read(key: 'k'), isNull);
    });
  });
}
