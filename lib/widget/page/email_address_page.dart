// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Patrick Zwick

import 'package:flutter/material.dart';

import '../../messages/app_localizations.dart';
import '../../model/result.dart';
import '../../service/services.dart';
import '../shared/email_address_text_field.dart';
import 'email_verification_page.dart';

enum AuthMode { login, register }

class EmailAddressPage extends StatefulWidget {
  final AuthMode mode;
  final bool termsAccepted;

  const EmailAddressPage({
    required this.mode,
    this.termsAccepted = false,
    super.key,
  });

  @override
  State<StatefulWidget> createState() => _EmailAddressPageState();
}

class _EmailAddressPageState extends State<EmailAddressPage> {
  bool _submitted = false;
  bool _loading = false;
  String? _validEmail;

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
              EmailAddressTextField(
                onSubmit: (email) => _validEmail = email,
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
                          const Icon(Icons.email_outlined, size: 16),
                          const SizedBox(width: 10),
                          Text(localizations.requestEmail),
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

    final email = _validEmail;

    if (email == null) {
      return;
    }

    setState(() => _loading = true);

    final Result<void> result;

    if (widget.mode == AuthMode.login) {
      result = await loginService.requestEmailLogin(email);
    } else {
      final locale = Localizations.localeOf(context).languageCode;
      result = await loginService.requestEmailRegistration(email, locale);
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
            EmailVerificationPage(
              email: email,
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
        EmailVerificationPage(
          email: email,
          mode: widget.mode,
          termsAccepted: widget.termsAccepted,
        ),
      ),
    );
  }
}

Route slideUpRoute(Widget page) {
  return PageRouteBuilder(
    pageBuilder: (context, animation, secondaryAnimation) => page,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      return SlideTransition(
        position: Tween(begin: const Offset(0.0, 1.0), end: Offset.zero)
            .animate(CurvedAnimation(parent: animation, curve: Curves.ease)),
        child: child,
      );
    },
  );
}
