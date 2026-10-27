// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Patrick Zwick

class PhoneLogin {
  final String phoneNumber;

  PhoneLogin({required this.phoneNumber});

  factory PhoneLogin.fromJson(Map<String, dynamic> json) {
    return PhoneLogin(phoneNumber: json['phoneNumber'] as String);
  }

  Map<String, dynamic> toJson() {
    return {'phoneNumber': phoneNumber};
  }
}
