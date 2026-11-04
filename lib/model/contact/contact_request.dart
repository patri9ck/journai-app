// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Patrick Zwick

import 'contact_type.dart';

class ContactRequest {
  final ContactType type;
  final String contact;

  ContactRequest({required this.type, required this.contact});

  Map<String, dynamic> toJson() {
    return {type.field: contact};
  }
}
