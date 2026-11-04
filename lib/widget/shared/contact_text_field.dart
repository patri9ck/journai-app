// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Patrick Zwick

import 'package:flutter/material.dart';

import '../../messages/app_localizations.dart';
import '../../model/contact/contact_type.dart';
import 'email_address_text_field.dart';
import 'phone_number_text_field.dart';

class ContactTextField extends StatelessWidget {
  final ContactType type;
  final void Function(String?) onSubmit;
  final bool submitted;

  const ContactTextField({required this.type, required this.onSubmit, required this.submitted, super.key});

  @override
  Widget build(BuildContext context) {
    return switch (type) {
      ContactType.email => EmailAddressTextField(onSubmit: onSubmit, submitted: submitted),
      ContactType.phone => PhoneNumberTextField(onSubmit: onSubmit, submitted: submitted),
    };
  }
}

IconData contactRequestIcon(ContactType type) => switch (type) {
  ContactType.email => Icons.email_outlined,
  ContactType.phone => Icons.sms_outlined,
};

String contactRequestLabel(ContactType type, AppLocalizations localizations) => switch (type) {
  ContactType.email => localizations.requestEmail,
  ContactType.phone => localizations.requestSms,
};
