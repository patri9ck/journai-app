// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Patrick Zwick

import 'data.dart';
import 'life_band_style.dart';

class MemoriesStyle {
  final int? id;
  final LifeBandStyle lifeBand;

  const MemoriesStyle({this.id, this.lifeBand = const LifeBandStyle()});

  static MemoriesStyle fromDataList(List<Data> data) {
    final entry = data.where((entry) => entry.feature == 'MEMORIES_STYLE').firstOrNull;

    if (entry == null) {
      return const MemoriesStyle();
    }

    return MemoriesStyle(
      id: entry.id,
      lifeBand: LifeBandStyle.fromJson(entry.fields['lifeBand'] as Map<String, dynamic>?),
    );
  }

  MemoriesStyle copyWith({LifeBandStyle? lifeBand}) => MemoriesStyle(id: id, lifeBand: lifeBand ?? this.lifeBand);

  Map<String, dynamic> toFields() => {'lifeBand': lifeBand.toJson()};
}
