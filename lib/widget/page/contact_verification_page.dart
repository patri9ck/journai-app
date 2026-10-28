// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Patrick Zwick

import 'package:flutter/material.dart';

import '../../messages/app_localizations.dart';
import '../../model/auth_mode.dart';
import '../../model/contact/contact_type.dart';
import '../../model/login/login.dart';
import '../../model/result.dart';
import '../../service/services.dart';
import '../../util/navigation.dart';
import '../shared/loading_button.dart';
import '../shared/verification_code_text_field.dart';

class ContactVerificationPage extends StatefulWidget {
  final ContactType type;
  final String contact;
  final AuthMode mode;
  final bool termsAccepted;
  final String? initialError;

  const ContactVerificationPage({
    required this.type,
    required this.contact,
    required this.mode,
    this.termsAccepted = false,
    this.initialError,
    super.key,
  });

  @override
  State<StatefulWidget> createState() => _ContactVerificationPageState();
}

class _ContactVerificationPageState extends State<ContactVerificationPage> {
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
                Text(_error!, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error)),
              ],
              const SizedBox(height: 32),
              VerificationCodeTextField(controller: _controller),
              const SizedBox(height: 16),
              LoadingButton(loading: _loading, onPressed: _submit, label: localizations.confirm),
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
      result = await loginService.verifyLogin(widget.type, widget.contact, code);
    } else {
      result = await loginService.verifyRegistration(widget.type, widget.contact, code, widget.termsAccepted);
    }

    if (!mounted) {
      return;
    }

    setState(() => _loading = false);

    if (result is Failure<Login>) {
      setState(() => _error = null);
      result.show(AppLocalizations.of(context)!);

      return;
    }

    navigateAfterLogin(Navigator.of(context));
  }
}
