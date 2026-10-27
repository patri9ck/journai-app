// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Patrick Zwick

class PhoneRegistration {
  final String phoneNumber;
  final String locale;

  PhoneRegistration({required this.phoneNumber, required this.locale});

  Map<String, dynamic> toJson() => {
    'phoneNumber': phoneNumber,
    'locale': locale,
  };
}
