// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Patrick Zwick

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../messages/app_localizations.dart';
import '../../model/login/login.dart';
import '../../model/result.dart';
import '../../service/services.dart';
import '../../util/navigation.dart';
import 'authenticate_sheet.dart';
import '../page/email_address_page.dart';
import '../page/phone_number_page.dart';

class RegisterSheet extends StatefulWidget {
  const RegisterSheet({super.key});

  @override
  State<RegisterSheet> createState() => _RegisterSheetState();
}

class _RegisterSheetState extends State<RegisterSheet> {
  bool _termsAccepted = false;
  String? _error;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return AuthenticateSheet(
      title: localizations.register,
      appleAccountAuthenticate: localizations.appleAccountRegister,
      googleAccountAuthenticate: localizations.googleAccountRegister,
      emailAddressAuthenticate: localizations.emailAddressRegister,
      phoneNumberAuthenticate: localizations.phoneNumberRegister,
      error: _error,
      onAppleAccountSubmit: _termsAccepted
          ? () async {
              setState(() => _error = null);

              final navigator = Navigator.of(context);
              final locale = Localizations.localeOf(context).languageCode;
              final localizations = AppLocalizations.of(context)!;

              final token = await appleAccountService.getIdentityToken();

              if (token == null || !mounted) {
                return;
              }

              final result = await loginService.registerWithApple(
                token,
                locale,
                _termsAccepted,
              );

              if (!mounted) {
                return;
              }

              if (result is Failure<Login>) {
                setState(() => _error = result.localizedMessage(localizations));

                return;
              }

              navigateAfterLogin(navigator);
            }
          : null,
      onGoogleAccountSubmit: _termsAccepted
          ? () async {
              setState(() => _error = null);

              final navigator = Navigator.of(context);
              final locale = Localizations.localeOf(context).languageCode;
              final localizations = AppLocalizations.of(context)!;

              final token = await googleAccountService.getIdToken();

              if (token == null || !mounted) {
                return;
              }

              final result = await loginService.registerWithGoogle(
                token,
                locale,
                _termsAccepted,
              );

              if (!mounted) {
                return;
              }

              if (result is Failure<Login>) {
                setState(() => _error = result.localizedMessage(localizations));

                return;
              }

              navigateAfterLogin(navigator);
            }
          : null,
      onEmailAddressSubmit: _termsAccepted
          ? () {
              Navigator.push(
                context,
                slideUpRoute(
                  EmailAddressPage(
                    mode: AuthMode.register,
                    termsAccepted: _termsAccepted,
                  ),
                ),
              );
            }
          : null,
      onPhoneNumberSubmit: _termsAccepted
          ? () {
              Navigator.push(
                context,
                slideUpRoute(
                  PhoneNumberPage(
                    mode: AuthMode.register,
                    termsAccepted: _termsAccepted,
                  ),
                ),
              );
            }
          : null,
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
