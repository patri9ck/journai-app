// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Patrick Zwick

class EmailLogin {
  final String emailAddress;

  EmailLogin({required this.emailAddress});

  factory EmailLogin.fromJson(Map<String, dynamic> json) {
    return EmailLogin(emailAddress: json['emailAddress'] as String);
  }

  Map<String, dynamic> toJson() {
    return {'emailAddress': emailAddress};
  }
}
