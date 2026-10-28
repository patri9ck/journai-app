// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Patrick Zwick

import 'poster_style.dart';

enum LifeBandFrame { none, line, double }

enum StampLayout { tidy, scattered }

enum StampSize { small, medium, large }

class LifeBandStyle {
  final PosterStyle poster;
  final LifeBandFrame frame;
  final bool showStripes;
  final bool showStamps;
  final StampLayout stampLayout;
  final StampSize stampSize;

  const LifeBandStyle({
    this.poster = const PosterStyle(),
    this.frame = LifeBandFrame.none,
    this.showStripes = true,
    this.showStamps = true,
    this.stampLayout = StampLayout.tidy,
    this.stampSize = StampSize.medium,
  });

  double get stampDimension => switch (stampSize) {
    StampSize.small => 64,
    StampSize.medium => 88,
    StampSize.large => 120,
  };

  static LifeBandStyle fromJson(Map<String, dynamic>? json) => LifeBandStyle(
    poster: PosterStyle.fromJson(json),
    frame: LifeBandFrame.values.asNameMap()[json?['frame']] ?? LifeBandFrame.none,
    showStripes: json?['showStripes'] as bool? ?? true,
    showStamps: json?['showStamps'] as bool? ?? true,
    stampLayout: StampLayout.values.asNameMap()[json?['stampLayout']] ?? StampLayout.tidy,
    stampSize: StampSize.values.asNameMap()[json?['stampSize']] ?? StampSize.medium,
  );

  LifeBandStyle copyWith({
    PosterStyle? poster,
    LifeBandFrame? frame,
    bool? showStripes,
    bool? showStamps,
    StampLayout? stampLayout,
    StampSize? stampSize,
  }) => LifeBandStyle(
    poster: poster ?? this.poster,
    frame: frame ?? this.frame,
    showStripes: showStripes ?? this.showStripes,
    showStamps: showStamps ?? this.showStamps,
    stampLayout: stampLayout ?? this.stampLayout,
    stampSize: stampSize ?? this.stampSize,
  );

  Map<String, dynamic> toJson() => {
    ...poster.toJson(),
    'frame': frame.name,
    'showStripes': showStripes,
    'showStamps': showStamps,
    'stampLayout': stampLayout.name,
    'stampSize': stampSize.name,
  };
}
