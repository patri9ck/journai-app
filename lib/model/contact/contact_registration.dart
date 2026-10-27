// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Patrick Zwick

import 'contact_type.dart';

class ContactRegistration {
  final ContactType type;
  final String contact;
  final String locale;

  ContactRegistration({required this.type, required this.contact, required this.locale});

  Map<String, dynamic> toJson() {
    return {type.field: contact, 'locale': locale};
  }
}
