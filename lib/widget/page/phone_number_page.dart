// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Patrick Zwick

import 'package:flutter/material.dart';

import '../../messages/app_localizations.dart';
import '../../model/result.dart';
import '../../service/services.dart';
import 'email_address_page.dart';
import '../shared/phone_number_text_field.dart';
import 'phone_verification_page.dart';

class PhoneNumberPage extends StatefulWidget {
  final AuthMode mode;
  final bool termsAccepted;

  const PhoneNumberPage({
    required this.mode,
    this.termsAccepted = false,
    super.key,
  });

  @override
  State<StatefulWidget> createState() => _PhoneNumberPageState();
}

class _PhoneNumberPageState extends State<PhoneNumberPage> {
  bool _submitted = false;
  bool _loading = false;
  String? _validPhone;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final title = widget.mode == AuthMode.login
        ? localizations.login
        : localizations.register;

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
              Text(
                localizations.emailCodeSubtitle,
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 32),
              PhoneNumberTextField(
                onSubmit: (phone) => _validPhone = phone,
                submitted: _submitted,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loading ? null : _submit,
                child: _loading
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.sms_outlined, size: 16),
                          const SizedBox(width: 10),
                          Text(localizations.requestSms),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    setState(() => _submitted = true);

    final phone = _validPhone;

    if (phone == null) {
      return;
    }

    setState(() => _loading = true);

    final Result<void> result;

    if (widget.mode == AuthMode.login) {
      result = await loginService.requestPhoneLogin(phone);
    } else {
      final locale = Localizations.localeOf(context).languageCode;
      result = await loginService.requestPhoneRegistration(phone, locale);
    }

    if (!mounted) {
      return;
    }

    setState(() => _loading = false);

    if (result is Failure<void>) {
      final localizations = AppLocalizations.of(context)!;
      final isPending = result is ServerFailure<void> && result.key == 'pending-verification';

      if (isPending) {
        Navigator.push(
          context,
          slideUpRoute(
            PhoneVerificationPage(
              phone: phone,
              mode: widget.mode,
              termsAccepted: widget.termsAccepted,
              initialError: result.localizedMessage(localizations),
            ),
          ),
        );

        return;
      }

      result.show(localizations);

      return;
    }

    Navigator.push(
      context,
      slideUpRoute(
        PhoneVerificationPage(
          phone: phone,
          mode: widget.mode,
          termsAccepted: widget.termsAccepted,
        ),
      ),
    );
  }
}
