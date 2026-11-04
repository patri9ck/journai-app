// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Patrick Zwick

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../messages/app_localizations.dart';
import '../../model/auth_mode.dart';
import '../../service/services.dart';
import 'authenticate_sheet.dart';

class RegisterSheet extends StatefulWidget {
  const RegisterSheet({super.key});

  @override
  State<RegisterSheet> createState() => _RegisterSheetState();
}

class _RegisterSheetState extends State<RegisterSheet> {
  bool _termsAccepted = false;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return AuthenticateSheet(
      mode: AuthMode.register,
      termsAccepted: _termsAccepted,
      caption: Column(
        children: [
          CheckboxListTile(
            value: _termsAccepted,
            onChanged: (value) => setState(() => _termsAccepted = value ?? false),
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
            title: RichText(
              text: TextSpan(
                style: theme.textTheme.bodySmall,
                children: [
                  TextSpan(text: localizations.registerCaption),
                  TextSpan(
                    text: ' ${localizations.termsOfService}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                    recognizer: TapGestureRecognizer()
                      ..onTap = () {
                        launchUrl(Uri.parse('${baseUrl}terms-of-service/'));
                      },
                  ),
                  TextSpan(text: ' ${localizations.and}'),
                  TextSpan(
                    text: ' ${localizations.privacyPolicy}.',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                    recognizer: TapGestureRecognizer()
                      ..onTap = () {
                        launchUrl(Uri.parse('${baseUrl}privacy-policy/'));
                      },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
