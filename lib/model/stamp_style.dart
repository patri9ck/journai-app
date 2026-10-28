// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Patrick Zwick

import 'dart:ui';

enum StampShape { circle, rectangle, oval, hexagon }

enum StampFont { sans, serif, typewriter }

const stampColors = [
  Color(0xFF2B2B33),
  Color(0xFF1F3A68),
  Color(0xFF1F6F78),
  Color(0xFF2E6B3F),
  Color(0xFF855F3D),
  Color(0xFFC0622B),
  Color(0xFFA4282B),
  Color(0xFF5B3B8C),
];

class StampStyle {
  final StampShape? shape;
  final StampFont font;
  final Color? color;

  const StampStyle({this.shape, this.font = StampFont.sans, this.color});

  static StampStyle fromFields(Map<String, dynamic> fields) {
    final color = fields['stampColor'] as int?;

    return StampStyle(
      shape: StampShape.values.asNameMap()[fields['stampShape']],
      font: StampFont.values.asNameMap()[fields['stampFont']] ?? StampFont.sans,
      color: color == null ? null : Color(color),
    );
  }

  Map<String, dynamic> toFields() => {
    if (shape != null) 'stampShape': shape!.name,
    'stampFont': font.name,
    if (color != null) 'stampColor': color!.toARGB32(),
  };
}
