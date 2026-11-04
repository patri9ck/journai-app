// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Patrick Zwick

DateTime? parseDocumentDate(String? text) {
  final trimmed = text?.trim() ?? '';

  if (trimmed.isEmpty) {
    return null;
  }

  final germanDate = RegExp(r'^(\d{1,2})\.(\d{1,2})\.(\d{4})$').firstMatch(trimmed);

  if (germanDate != null) {
    return DateTime(
      int.parse(germanDate.group(3)!),
      int.parse(germanDate.group(2)!),
      int.parse(germanDate.group(1)!),
    );
  }

  return DateTime.tryParse(trimmed);
}

String formatDocumentDate(DateTime date) =>
    '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
