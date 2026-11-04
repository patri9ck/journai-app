// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Patrick Zwick

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../messages/app_localizations.dart';
import '../../model/stamp_style.dart';

TextStyle stampFontStyle(StampFont font, TextStyle style) => switch (font) {
  StampFont.sans => GoogleFonts.inter(textStyle: style),
  StampFont.serif => GoogleFonts.instrumentSerif(textStyle: style),
  StampFont.typewriter => style.copyWith(fontFamily: 'monospace', fontFamilyFallback: const ['Courier']),
};

String stampFontLabel(AppLocalizations localizations, StampFont font) => switch (font) {
  StampFont.sans => localizations.stampFontSans,
  StampFont.serif => localizations.stampFontSerif,
  StampFont.typewriter => localizations.stampFontTypewriter,
};
