// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Patrick Zwick

import 'dart:io';

import 'package:flutter/material.dart';

import '../../messages/app_localizations.dart';

class AuthenticateSheet extends StatelessWidget {
  final String _title;
  final String? _appleAccountAuthenticate;
  final String _googleAccountAuthenticate;
  final String _emailAddressAuthenticate;
  final String _phoneNumberAuthenticate;
  final void Function()? _onAppleAccountSubmit;
  final void Function()? _onGoogleAccountSubmit;
  final void Function()? _onEmailAddressSubmit;
  final void Function()? _onPhoneNumberSubmit;
  final Widget _caption;
  final String? _error;

  const AuthenticateSheet({
    required String title,
    String? appleAccountAuthenticate,
    required String googleAccountAuthenticate,
    required String emailAddressAuthenticate,
    required String phoneNumberAuthenticate,
    void Function()? onAppleAccountSubmit,
    void Function()? onGoogleAccountSubmit,
    void Function()? onEmailAddressSubmit,
    void Function()? onPhoneNumberSubmit,
    required Widget caption,
    String? error,
    super.key,
  }) : _title = title,
       _appleAccountAuthenticate = appleAccountAuthenticate,
       _googleAccountAuthenticate = googleAccountAuthenticate,
       _emailAddressAuthenticate = emailAddressAuthenticate,
       _phoneNumberAuthenticate = phoneNumberAuthenticate,
       _onAppleAccountSubmit = onAppleAccountSubmit,
       _onGoogleAccountSubmit = onGoogleAccountSubmit,
       _onEmailAddressSubmit = onEmailAddressSubmit,
       _onPhoneNumberSubmit = onPhoneNumberSubmit,
       _caption = caption,
       _error = error;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

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
                Text(_title, style: theme.textTheme.headlineMedium),
                const SizedBox(height: 24),
                if (Platform.isIOS && _appleAccountAuthenticate != null && _onAppleAccountSubmit != null) ...[
                  ElevatedButton(
                    onPressed: _onAppleAccountSubmit,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.apple, size: 18),
                        const SizedBox(width: 10),
                        Text(_appleAccountAuthenticate),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                ElevatedButton(
                  onPressed: _onGoogleAccountSubmit,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ColorFiltered(
                        colorFilter: const ColorFilter.mode(
                          Colors.white,
                          BlendMode.srcIn,
                        ),
                        child: Image.asset('assets/google.png', width: 16),
                      ),
                      const SizedBox(width: 10),
                      Text(_googleAccountAuthenticate),
                    ],
                  ),
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
                OutlinedButton(
                  onPressed: _onEmailAddressSubmit,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.email_outlined, size: 18),
                      const SizedBox(width: 10),
                      Text(_emailAddressAuthenticate),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: _onPhoneNumberSubmit,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.phone_outlined, size: 18),
                      const SizedBox(width: 10),
                      Text(_phoneNumberAuthenticate),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Center(child: _caption),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _error,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.error,
                    ),
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
}
