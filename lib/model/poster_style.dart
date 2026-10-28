// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Patrick Zwick

import 'dart:ui';

import 'stamp_style.dart';

const posterBackgrounds = [
  Color(0xFFFBF8F1),
  Color(0xFFF3EEDF),
  Color(0xFFFFFFFF),
  Color(0xFFE6D3AE),
  Color(0xFFDDE5D3),
  Color(0xFFDCE7F0),
  Color(0xFFF2DEDC),
];

class PosterStyle {
  final Color background;
  final StampFont headingFont;

  const PosterStyle({this.background = const Color(0xFFFBF8F1), this.headingFont = StampFont.serif});

  static PosterStyle fromJson(Map<String, dynamic>? json) {
    final background = json?['background'] as int?;

    return PosterStyle(
      background: background == null ? const Color(0xFFFBF8F1) : Color(background),
      headingFont: StampFont.values.asNameMap()[json?['headingFont']] ?? StampFont.serif,
    );
  }

  PosterStyle copyWith({Color? background, StampFont? headingFont}) =>
      PosterStyle(background: background ?? this.background, headingFont: headingFont ?? this.headingFont);

  Map<String, dynamic> toJson() => {
    'background': background.toARGB32(),
    'headingFont': headingFont.name,
  };
}
