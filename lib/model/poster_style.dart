// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Patrick Zwick

import 'dart:ui';

import 'stamp_style.dart';

enum PosterFrame { none, line, double }

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
  final String heading;
  final StampFont headingFont;
  final PosterFrame frame;
  final Color frameColor;

  const PosterStyle({
    this.background = const Color(0xFFFBF8F1),
    this.heading = '',
    this.headingFont = StampFont.serif,
    this.frame = PosterFrame.none,
    this.frameColor = const Color(0xFF2B2B33),
  });

  static PosterStyle fromJson(Map<String, dynamic>? json) {
    final background = json?['background'] as int?;
    final frameColor = json?['frameColor'] as int?;

    return PosterStyle(
      background: background == null ? const Color(0xFFFBF8F1) : Color(background),
      heading: json?['heading'] as String? ?? '',
      headingFont: StampFont.values.asNameMap()[json?['headingFont']] ?? StampFont.serif,
      frame: PosterFrame.values.asNameMap()[json?['frame']] ?? PosterFrame.none,
      frameColor: frameColor == null ? const Color(0xFF2B2B33) : Color(frameColor),
    );
  }

  PosterStyle copyWith({Color? background, String? heading, StampFont? headingFont, PosterFrame? frame, Color? frameColor}) =>
      PosterStyle(
        background: background ?? this.background,
        heading: heading ?? this.heading,
        headingFont: headingFont ?? this.headingFont,
        frame: frame ?? this.frame,
        frameColor: frameColor ?? this.frameColor,
      );

  String headingOr(String defaultHeading) => heading.trim().isEmpty ? defaultHeading : heading.trim();

  Map<String, dynamic> toJson() => {
    'background': background.toARGB32(),
    'heading': heading.trim(),
    'headingFont': headingFont.name,
    'frame': frame.name,
    'frameColor': frameColor.toARGB32(),
  };
}
