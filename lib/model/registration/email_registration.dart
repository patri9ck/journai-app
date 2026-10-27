// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Patrick Zwick

class EmailRegistration {
  final String emailAddress;
  final String locale;

  EmailRegistration({required this.emailAddress, required this.locale});

  Map<String, dynamic> toJson() => {
    'emailAddress': emailAddress,
    'locale': locale,
  };
}
