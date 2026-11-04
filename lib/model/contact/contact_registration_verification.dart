// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Patrick Zwick

import 'contact_type.dart';

class ContactRegistrationVerification {
  final ContactType type;
  final String contact;
  final String code;
  final String publicKey;
  final bool termsAccepted;

  ContactRegistrationVerification({
    required this.type,
    required this.contact,
    required this.code,
    required this.publicKey,
    required this.termsAccepted,
  });

  Map<String, dynamic> toJson() {
    return {type.field: contact, 'code': code, 'publicKey': publicKey, 'termsAccepted': termsAccepted};
  }
}
