// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Patrick Zwick

import 'package:flutter/material.dart';

import '../../messages/app_localizations.dart';
import '../../model/login/login.dart';
import '../../model/result.dart';
import '../../service/services.dart';
import '../../util/navigation.dart';
import '../shared/verification_code_text_field.dart';
import 'email_address_page.dart';

class EmailVerificationPage extends StatefulWidget {
  final String email;
  final AuthMode mode;
  final bool termsAccepted;
  final String? initialError;

  const EmailVerificationPage({
    required this.email,
    required this.mode,
    this.termsAccepted = false,
    this.initialError,
    super.key,
  });

  @override
  State<StatefulWidget> createState() => _EmailVerificationPageState();
}

class _EmailVerificationPageState extends State<EmailVerificationPage> {
  final _controller = TextEditingController();
  bool _loading = false;
  late String? _error = widget.initialError;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(localizations.checkInbox, style: theme.textTheme.headlineMedium),
              const SizedBox(height: 8),
              Text(localizations.enterCodeFromInbox, style: theme.textTheme.bodySmall),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error),
                ),
              ],
              const SizedBox(height: 32),
              VerificationCodeTextField(controller: _controller),
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
                    : Text(localizations.confirm),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    final code = _controller.text.trim();

    if (code.length < 6) {
      return;
    }

    setState(() => _loading = true);

    final Result<Login> result;

    if (widget.mode == AuthMode.login) {
      result = await loginService.verifyEmailLogin(widget.email, code);
    } else {
      result = await loginService.verifyEmailRegistration(
        widget.email,
        code,
        widget.termsAccepted,
      );
    }

    if (!mounted) {
      return;
    }

    setState(() => _loading = false);

    if (result is Failure<Login>) {
      setState(() => _error = null);
      result.show(AppLocalizations.of(context));

      return;
    }

    navigateAfterLogin(Navigator.of(context));
  }
}
