// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Patrick Zwick

import '../util/document_date.dart';
import 'data.dart';

class JournalEntry {
  final int? id;
  final int tripId;
  final DateTime date;
  final String text;
  final String? sound;

  const JournalEntry({this.id, required this.tripId, required this.date, required this.text, this.sound});

  static JournalEntry? fromData(Data data) {
    final tripId = data.fields['tripId'] as int?;
    final date = parseDocumentDate(data.fields['date'] as String?);

    if (tripId == null || date == null) {
      return null;
    }

    return JournalEntry(
      id: data.id,
      tripId: tripId,
      date: date,
      text: data.fields['text'] as String? ?? '',
      sound: data.fields['sound'] as String?,
    );
  }

  static List<JournalEntry> fromDataList(List<Data> data, int tripId) => data
      .where((entry) => entry.feature == 'JOURNAL_ENTRY')
      .map(fromData)
      .whereType<JournalEntry>()
      .where((entry) => entry.tripId == tripId)
      .toList();

  Map<String, dynamic> toFields() => {
    'tripId': tripId,
    'date': date.toIso8601String().substring(0, 10),
    'text': text,
    if (sound != null) 'sound': sound,
  };
}
