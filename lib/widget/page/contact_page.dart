// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Patrick Zwick

import 'package:flutter/material.dart';

import '../../messages/app_localizations.dart';
import '../../model/auth_mode.dart';
import '../../model/contact/contact_type.dart';
import '../../model/result.dart';
import '../../service/services.dart';
import '../../util/navigation.dart';
import '../shared/contact_text_field.dart';
import '../shared/loading_button.dart';
import 'contact_verification_page.dart';

class ContactPage extends StatefulWidget {
  final ContactType type;
  final AuthMode mode;
  final bool termsAccepted;

  const ContactPage({required this.type, required this.mode, this.termsAccepted = false, super.key});

  @override
  State<StatefulWidget> createState() => _ContactPageState();
}

class _ContactPageState extends State<ContactPage> {
  bool _submitted = false;
  bool _loading = false;
  String? _validContact;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final title = widget.mode == AuthMode.login ? localizations.login : localizations.register;

    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(title, style: theme.textTheme.headlineMedium),
              const SizedBox(height: 8),
              Text(localizations.emailCodeSubtitle, style: theme.textTheme.bodySmall),
              const SizedBox(height: 32),
              ContactTextField(
                type: widget.type,
                onSubmit: (contact) => _validContact = contact,
                submitted: _submitted,
              ),
              const SizedBox(height: 16),
              LoadingButton(
                loading: _loading,
                onPressed: _submit,
                label: contactRequestLabel(widget.type, localizations),
                icon: contactRequestIcon(widget.type),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    setState(() => _submitted = true);

    final contact = _validContact;

    if (contact == null) {
      return;
    }

    setState(() => _loading = true);

    final Result<void> result;

    if (widget.mode == AuthMode.login) {
      result = await loginService.requestLogin(widget.type, contact);
    } else {
      final locale = Localizations.localeOf(context).languageCode;

      result = await loginService.requestRegistration(widget.type, contact, locale);
    }

    if (!mounted) {
      return;
    }

    setState(() => _loading = false);

    if (result is Failure<void>) {
      final localizations = AppLocalizations.of(context)!;
      final isPending = result is ServerFailure<void> && result.key == 'pending-verification';

      if (!isPending) {
        result.show(localizations);

        return;
      }

      _openVerification(contact, initialError: result.localizedMessage(localizations));

      return;
    }

    _openVerification(contact);
  }

  void _openVerification(String contact, {String? initialError}) {
    Navigator.push(
      context,
      slideUpRoute(
        ContactVerificationPage(
          type: widget.type,
          contact: contact,
          mode: widget.mode,
          termsAccepted: widget.termsAccepted,
          initialError: initialError,
        ),
      ),
    );
  }
}
