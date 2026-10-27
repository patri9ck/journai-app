// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Patrick Zwick

import 'dart:convert';
import 'dart:io';

import 'package:integration_test/integration_test_driver.dart';

Future<void> main() => integrationDriver(
  responseDataCallback: (data) async {
    final outputDirectory = Platform.environment['SCREENSHOT_OUTPUT'] ?? 'build/screenshots/raw';
    final screenshots = Map<String, String>.from(data?['screenshots'] as Map? ?? {});

    for (final entry in screenshots.entries) {
      final file = File('$outputDirectory/${entry.key}.png');

      await file.parent.create(recursive: true);
      await file.writeAsBytes(base64Decode(entry.value));
    }
  },
);
