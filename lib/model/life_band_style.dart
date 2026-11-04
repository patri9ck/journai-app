// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Patrick Zwick

import 'poster_style.dart';

enum StampLayout { tidy, scattered }

enum StampSize { small, medium, large }

class LifeBandStyle {
  final PosterStyle poster;
  final bool showStripes;
  final bool showStamps;
  final StampLayout stampLayout;
  final StampSize stampSize;

  const LifeBandStyle({
    this.poster = const PosterStyle(),
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
    showStripes: json?['showStripes'] as bool? ?? true,
    showStamps: json?['showStamps'] as bool? ?? true,
    stampLayout: StampLayout.values.asNameMap()[json?['stampLayout']] ?? StampLayout.tidy,
    stampSize: StampSize.values.asNameMap()[json?['stampSize']] ?? StampSize.medium,
  );

  LifeBandStyle copyWith({
    PosterStyle? poster,
    bool? showStripes,
    bool? showStamps,
    StampLayout? stampLayout,
    StampSize? stampSize,
  }) => LifeBandStyle(
    poster: poster ?? this.poster,
    showStripes: showStripes ?? this.showStripes,
    showStamps: showStamps ?? this.showStamps,
    stampLayout: stampLayout ?? this.stampLayout,
    stampSize: stampSize ?? this.stampSize,
  );

  Map<String, dynamic> toJson() => {
    ...poster.toJson(),
    'showStripes': showStripes,
    'showStamps': showStamps,
    'stampLayout': stampLayout.name,
    'stampSize': stampSize.name,
  };
}
