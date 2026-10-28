// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Patrick Zwick

import 'poster_style.dart';

enum StampBookFrame { none, line, double }

enum StampBookLayout { tidy, scattered }

enum StampBookSize { small, medium, large }

class StampBookStyle {
  final PosterStyle poster;
  final StampBookFrame frame;
  final StampBookLayout layout;
  final StampBookSize size;

  const StampBookStyle({
    this.poster = const PosterStyle(),
    this.frame = StampBookFrame.none,
    this.layout = StampBookLayout.tidy,
    this.size = StampBookSize.medium,
  });

  double get stampSize => switch (size) {
    StampBookSize.small => 100,
    StampBookSize.medium => 140,
    StampBookSize.large => 180,
  };

  static StampBookStyle fromJson(Map<String, dynamic>? json) => StampBookStyle(
    poster: PosterStyle.fromJson(json),
    frame: StampBookFrame.values.asNameMap()[json?['frame']] ?? StampBookFrame.none,
    layout: StampBookLayout.values.asNameMap()[json?['layout']] ?? StampBookLayout.tidy,
    size: StampBookSize.values.asNameMap()[json?['size']] ?? StampBookSize.medium,
  );

  StampBookStyle copyWith({PosterStyle? poster, StampBookFrame? frame, StampBookLayout? layout, StampBookSize? size}) =>
      StampBookStyle(
        poster: poster ?? this.poster,
        frame: frame ?? this.frame,
        layout: layout ?? this.layout,
        size: size ?? this.size,
      );

  Map<String, dynamic> toJson() => {
    ...poster.toJson(),
    'frame': frame.name,
    'layout': layout.name,
    'size': size.name,
  };
}
