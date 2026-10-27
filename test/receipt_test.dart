// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Patrick Zwick

import 'package:flutter_test/flutter_test.dart';
import 'package:journai_app/model/receipt.dart';

void main() {
  const rates = {'EUR': 1.0, 'THB': 40.0};

  test('amounts are converted to euros', () {
    expect(receiptAmountInEuro({'amount': 800, 'currency': 'THB'}, rates), 20);
    expect(receiptAmountInEuro({'amount': 12.5, 'currency': 'eur'}, rates), 12.5);
    expect(receiptAmountInEuro({'amount': 12.5}, rates), 12.5);
  });

  test('amounts that cannot be converted are left out', () {
    expect(receiptAmountInEuro({'amount': 10, 'currency': 'XYZ'}, rates), isNull);
    expect(receiptAmountInEuro({'currency': 'EUR'}, rates), isNull);
    expect(receiptAmountInEuro({'amount': 10, 'currency': 'EUR'}, null), isNull);
  });
}
