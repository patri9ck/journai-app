// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Patrick Zwick

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('every used font is bundled, so nothing is loaded from Google', () async {
    GoogleFonts.config.allowRuntimeFetching = false;

    final styles = [
      for (final fontStyle in FontStyle.values)
        for (final fontWeight in [FontWeight.w400, FontWeight.w500, FontWeight.w600, FontWeight.w700])
          GoogleFonts.inter(fontWeight: fontWeight, fontStyle: fontStyle),
      GoogleFonts.instrumentSerif(),
      GoogleFonts.instrumentSerif(fontStyle: FontStyle.italic),
    ];

    await expectLater(GoogleFonts.pendingFonts(styles), completes);
  });
}
