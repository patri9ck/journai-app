// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Patrick Zwick

import '../util/document_date.dart';
import 'data.dart';
import 'poster_style.dart';
import 'stamp_style.dart';

class Trip {
  final int? id;
  final String countryCode;
  final String countryName;
  final DateTime start;
  final DateTime end;
  final StampStyle stampStyle;
  final PosterStyle albumStyle;

  const Trip({
    this.id,
    required this.countryCode,
    required this.countryName,
    required this.start,
    required this.end,
    this.stampStyle = const StampStyle(),
    this.albumStyle = const PosterStyle(),
  });

  static Trip? fromData(Data data) {
    final start = parseDocumentDate(data.fields['start'] as String?);
    final end = parseDocumentDate(data.fields['end'] as String?);
    final countryCode = data.fields['countryCode'] as String?;

    if (start == null || end == null || countryCode == null) {
      return null;
    }

    return Trip(
      id: data.id,
      countryCode: countryCode,
      countryName: data.fields['countryName'] as String? ?? countryCode,
      start: start,
      end: end,
      stampStyle: StampStyle.fromFields(data.fields),
      albumStyle: PosterStyle.fromJson(data.fields['albumStyle'] as Map<String, dynamic>?),
    );
  }

  Trip copyWith({DateTime? start, DateTime? end, StampStyle? stampStyle, PosterStyle? albumStyle}) => Trip(
    id: id,
    countryCode: countryCode,
    countryName: countryName,
    start: start ?? this.start,
    end: end ?? this.end,
    stampStyle: stampStyle ?? this.stampStyle,
    albumStyle: albumStyle ?? this.albumStyle,
  );

  static List<Trip> fromDataList(List<Data> data) =>
      data.where((entry) => entry.feature == 'TRIP').map(fromData).whereType<Trip>().toList()
        ..sort((first, second) => first.start.compareTo(second.start));

  bool isOver(DateTime today) => end.isBefore(today);

  List<DateTime> get days => [
    for (var day = start; !day.isAfter(end); day = DateTime(day.year, day.month, day.day + 1)) day,
  ];

  bool contains(DateTime date) => !date.isBefore(start) && !date.isAfter(end);

  Map<String, dynamic> toFields() => {
    'countryCode': countryCode,
    'countryName': countryName,
    'start': start.toIso8601String().substring(0, 10),
    'end': end.toIso8601String().substring(0, 10),
    ...stampStyle.toFields(),
    'albumStyle': albumStyle.toJson(),
  };
}
