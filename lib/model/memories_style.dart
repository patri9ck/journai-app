// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Patrick Zwick

import 'data.dart';
import 'poster_style.dart';
import 'stamp_book_style.dart';

class MemoriesStyle {
  final int? id;
  final PosterStyle lifeBand;
  final StampBookStyle stampBook;

  const MemoriesStyle({this.id, this.lifeBand = const PosterStyle(), this.stampBook = const StampBookStyle()});

  static MemoriesStyle fromDataList(List<Data> data) {
    final entry = data.where((entry) => entry.feature == 'MEMORIES_STYLE').firstOrNull;

    if (entry == null) {
      return const MemoriesStyle();
    }

    return MemoriesStyle(
      id: entry.id,
      lifeBand: PosterStyle.fromJson(entry.fields['lifeBand'] as Map<String, dynamic>?),
      stampBook: StampBookStyle.fromJson(entry.fields['stampBook'] as Map<String, dynamic>?),
    );
  }

  MemoriesStyle copyWith({PosterStyle? lifeBand, StampBookStyle? stampBook}) =>
      MemoriesStyle(id: id, lifeBand: lifeBand ?? this.lifeBand, stampBook: stampBook ?? this.stampBook);

  Map<String, dynamic> toFields() => {
    'lifeBand': lifeBand.toJson(),
    'stampBook': stampBook.toJson(),
  };
}
