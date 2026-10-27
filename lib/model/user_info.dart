// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Patrick Zwick

class UserInfo {
  final String? email;
  final String? phone;
  final bool googleLinked;
  final bool appleLinked;

  const UserInfo({
    required this.email,
    required this.phone,
    required this.googleLinked,
    required this.appleLinked,
  });

  factory UserInfo.fromJson(Map<String, dynamic> json) {
    return UserInfo(
      email: json['email'] as String?,
      phone: json['phone'] as String?,
      googleLinked: json['googleLinked'] as bool? ?? false,
      appleLinked: json['appleLinked'] as bool? ?? false,
    );
  }

  int get loginMethodCount {
    return [
      email != null,
      phone != null,
      googleLinked,
      appleLinked,
    ].where((isSet) => isSet).length;
  }
}
