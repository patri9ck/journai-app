// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Patrick Zwick

import 'dart:io';

import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/services.dart';

const brandColor = Color(0xFF3478F0);

DynamicPalette? dynamicPalette;

Color get emergencyCardColor => dynamicPalette?.lightPrimary ?? brandColor;

class DynamicPalette {
  final Color lightPrimary;
  final Color darkPrimary;

  const DynamicPalette({required this.lightPrimary, required this.darkPrimary});
}

Future<DynamicPalette?> loadDynamicPalette() async {
  if (!Platform.isAndroid) {
    return null;
  }

  try {
    final corePalette = await DynamicColorPlugin.getCorePalette();

    if (corePalette == null) {
      return null;
    }

    return DynamicPalette(
      lightPrimary: Color(corePalette.primary.get(40)),
      darkPrimary: Color(corePalette.primary.get(65)),
    );
  } on PlatformException {
    return null;
  }
}
