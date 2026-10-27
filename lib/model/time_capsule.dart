// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Patrick Zwick

import '../util/document_date.dart';
import 'data.dart';

class TimeCapsule {
  final int? id;
  final int tripId;
  final String text;
  final DateTime writtenAt;
  final DateTime opensAt;

  const TimeCapsule({this.id, required this.tripId, required this.text, required this.writtenAt, required this.opensAt});

  static TimeCapsule? fromData(Data data) {
    final tripId = data.fields['tripId'] as int?;
    final writtenAt = parseDocumentDate(data.fields['writtenAt'] as String?);
    final opensAt = parseDocumentDate(data.fields['opensAt'] as String?);

    if (tripId == null || writtenAt == null || opensAt == null) {
      return null;
    }

    return TimeCapsule(
      id: data.id,
      tripId: tripId,
      text: data.fields['text'] as String? ?? '',
      writtenAt: writtenAt,
      opensAt: opensAt,
    );
  }

  static List<TimeCapsule> fromDataList(List<Data> data) =>
      data.where((entry) => entry.feature == 'TIME_CAPSULE').map(fromData).whereType<TimeCapsule>().toList();

  bool isOpen(DateTime today) => !opensAt.isAfter(today);

  Map<String, dynamic> toFields() => {
    'tripId': tripId,
    'text': text,
    'writtenAt': writtenAt.toIso8601String().substring(0, 10),
    'opensAt': opensAt.toIso8601String().substring(0, 10),
  };
}
