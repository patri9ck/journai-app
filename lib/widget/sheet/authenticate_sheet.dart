// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Patrick Zwick

import 'dart:io';

import 'package:flutter/material.dart';

import '../../messages/app_localizations.dart';
import '../../model/auth_mode.dart';
import '../../model/contact/contact_type.dart';
import '../../model/login/external_account_type.dart';
import '../../model/login/login.dart';
import '../../model/result.dart';
import '../../service/services.dart';
import '../../util/navigation.dart';
import '../page/contact_page.dart';

class AuthenticateSheet extends StatefulWidget {
  final AuthMode mode;
  final bool termsAccepted;
  final Widget caption;

  const AuthenticateSheet({required this.mode, this.termsAccepted = false, required this.caption, super.key});

  @override
  State<AuthenticateSheet> createState() => _AuthenticateSheetState();
}

class _AuthenticateSheetState extends State<AuthenticateSheet> {
  String? _error;

  bool get _enabled => widget.mode == AuthMode.login || widget.termsAccepted;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final isLogin = widget.mode == AuthMode.login;

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: 12, bottom: 24),
              decoration: BoxDecoration(
                color: theme.colorScheme.outline,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(isLogin ? localizations.login : localizations.register, style: theme.textTheme.headlineMedium),
                const SizedBox(height: 24),
                if (Platform.isIOS) ...[
                  _button(
                    icon: const Icon(Icons.apple, size: 18),
                    label: isLogin ? localizations.appleAccountLogin : localizations.appleAccountRegister,
                    onPressed: () => _authenticateWithExternalAccount(ExternalAccountType.apple),
                  ),
                  const SizedBox(height: 8),
                ],
                _button(
                  icon: ColorFiltered(
                    colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
                    child: Image.asset('assets/google.png', width: 16),
                  ),
                  label: isLogin ? localizations.googleAccountLogin : localizations.googleAccountRegister,
                  onPressed: () => _authenticateWithExternalAccount(ExternalAccountType.google),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    const Expanded(child: Divider()),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(localizations.or, style: theme.textTheme.bodySmall),
                    ),
                    const Expanded(child: Divider()),
                  ],
                ),
                const SizedBox(height: 20),
                _button(
                  icon: const Icon(Icons.email_outlined, size: 18),
                  label: isLogin ? localizations.emailAddressLogin : localizations.emailAddressRegister,
                  onPressed: () => _authenticateWithContact(ContactType.email),
                  outlined: true,
                ),
                const SizedBox(height: 8),
                _button(
                  icon: const Icon(Icons.phone_outlined, size: 18),
                  label: isLogin ? localizations.phoneNumberLogin : localizations.phoneNumberRegister,
                  onPressed: () => _authenticateWithContact(ContactType.phone),
                  outlined: true,
                ),
                const SizedBox(height: 24),
                Center(child: widget.caption),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _error!,
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error),
                    textAlign: TextAlign.center,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _button({
    required Widget icon,
    required String label,
    required VoidCallback onPressed,
    bool outlined = false,
  }) {
    final child = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [icon, const SizedBox(width: 10), Text(label)],
    );

    if (outlined) {
      return OutlinedButton(onPressed: _enabled ? onPressed : null, child: child);
    }

    return ElevatedButton(onPressed: _enabled ? onPressed : null, child: child);
  }

  Future<void> _authenticateWithExternalAccount(ExternalAccountType type) async {
    setState(() => _error = null);

    final navigator = Navigator.of(context);
    final localizations = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).languageCode;

    final result = await loginService.authenticateWithExternalAccount(type, widget.mode, locale, widget.termsAccepted);

    if (result == null || !mounted) {
      return;
    }

    if (result is Failure<Login>) {
      setState(() => _error = result.localizedMessage(localizations));

      return;
    }

    navigateAfterLogin(navigator);
  }

  void _authenticateWithContact(ContactType type) {
    Navigator.push(
      context,
      slideUpRoute(ContactPage(type: type, mode: widget.mode, termsAccepted: widget.termsAccepted)),
    );
  }
}
