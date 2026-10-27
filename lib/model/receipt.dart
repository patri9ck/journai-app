// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Patrick Zwick

double? receiptAmountInEuro(Map<String, dynamic> fields, Map<String, double>? euroRates) {
  final amount = (fields['amount'] as num?)?.toDouble();
  final currency = (fields['currency'] as String? ?? 'EUR').toUpperCase();
  final rate = euroRates?[currency];

  if (amount == null || rate == null || rate == 0) {
    return null;
  }

  return amount / rate;
}
