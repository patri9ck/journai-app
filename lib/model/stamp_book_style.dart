// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Patrick Zwick

import 'dart:ui';

enum StampBookFrame { none, line, double }

enum StampBookLayout { tidy, scattered }

enum StampBookSize { small, medium, large }

const stampBookBackgrounds = [
  Color(0xFFF3EEDF),
  Color(0xFFFFFFFF),
  Color(0xFFE6D3AE),
  Color(0xFFDDE5D3),
  Color(0xFFDCE7F0),
  Color(0xFFF2DEDC),
];

class StampBookStyle {
  final Color background;
  final StampBookFrame frame;
  final StampBookLayout layout;
  final StampBookSize size;

  const StampBookStyle({
    this.background = const Color(0xFFF3EEDF),
    this.frame = StampBookFrame.none,
    this.layout = StampBookLayout.tidy,
    this.size = StampBookSize.medium,
  });

  double get stampSize => switch (size) {
    StampBookSize.small => 100,
    StampBookSize.medium => 140,
    StampBookSize.large => 180,
  };

  static StampBookStyle fromJson(Map<String, dynamic> json) {
    final background = json['background'] as int?;

    return StampBookStyle(
      background: background == null ? const Color(0xFFF3EEDF) : Color(background),
      frame: StampBookFrame.values.asNameMap()[json['frame']] ?? StampBookFrame.none,
      layout: StampBookLayout.values.asNameMap()[json['layout']] ?? StampBookLayout.tidy,
      size: StampBookSize.values.asNameMap()[json['size']] ?? StampBookSize.medium,
    );
  }

  Map<String, dynamic> toJson() => {
    'background': background.toARGB32(),
    'frame': frame.name,
    'layout': layout.name,
    'size': size.name,
  };
}
