// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Patrick Zwick

import 'dart:convert';
import 'dart:isolate';

import 'storage.dart';

Future<void> saveListCache(String key, List<Map<String, dynamic>> items) async {
  await storage.write(key: key, value: jsonEncode(items));
}

Future<List<Map<String, dynamic>>?> readListCache(String key) async {
  final raw = await storage.read(key: key);

  if (raw == null) {
    return null;
  }

  try {
    return await Isolate.run(
      () => (jsonDecode(raw) as List).map((item) => Map<String, dynamic>.from(item as Map)).toList(),
    );
  } on FormatException {
    return null;
  } on TypeError {
    return null;
  }
}

Future<void> saveObjectCache(String key, Map<String, dynamic> value) async {
  await storage.write(key: key, value: jsonEncode(value));
}

Future<Map<String, dynamic>?> readObjectCache(String key) async {
  final raw = await storage.read(key: key);

  if (raw == null) {
    return null;
  }

  try {
    return Map<String, dynamic>.from(jsonDecode(raw) as Map);
  } on FormatException {
    return null;
  } on TypeError {
    return null;
  }
}
