// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Patrick Zwick

import 'contact_type.dart';

class ContactVerification {
  final ContactType type;
  final String contact;
  final String code;

  ContactVerification({required this.type, required this.contact, required this.code});

  Map<String, dynamic> toJson() {
    return {type.field: contact, 'code': code};
  }
}
