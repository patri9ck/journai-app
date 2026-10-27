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

class LoginSheet extends StatefulWidget {
  const LoginSheet({super.key});

  @override
  State<LoginSheet> createState() => _LoginSheetState();
}

class _LoginSheetState extends State<LoginSheet> {
  String? _error;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;

    return AuthenticateSheet(
      title: localizations.login,
      appleAccountAuthenticate: localizations.appleAccountLogin,
      googleAccountAuthenticate: localizations.googleAccountLogin,
      emailAddressAuthenticate: localizations.emailAddressLogin,
      phoneNumberAuthenticate: localizations.phoneNumberLogin,
      error: _error,
      onAppleAccountSubmit: () async {
        setState(() => _error = null);

        final navigator = Navigator.of(context);
        final token = await appleAccountService.getIdentityToken();

        if (token == null || !mounted) {
          return;
        }

        final result = await loginService.loginWithApple(token);

        if (!mounted) {
          return;
        }

        if (result is Failure<Login>) {
          setState(() => _error = result.localizedMessage(localizations));

          return;
        }

        navigateAfterLogin(navigator);
      },
      onGoogleAccountSubmit: () async {
        setState(() => _error = null);

        final navigator = Navigator.of(context);
        final token = await googleAccountService.getIdToken();

        if (token == null || !mounted) {
          return;
        }

        final result = await loginService.loginWithGoogle(token);

        if (!mounted) {
          return;
        }

        if (result is Failure<Login>) {
          setState(() => _error = result.localizedMessage(localizations));

          return;
        }

        navigateAfterLogin(navigator);
      },
      onEmailAddressSubmit: () {
        Navigator.push(
          context,
          slideUpRoute(EmailAddressPage(mode: AuthMode.login)),
        );
      },
      onPhoneNumberSubmit: () {
        Navigator.push(context, slideUpRoute(PhoneNumberPage(mode: AuthMode.login)));
      },
      caption: RichText(
        textAlign: TextAlign.center,
        text: TextSpan(
          children: [
            TextSpan(text: localizations.loginCaption),
            TextSpan(
              text: ' ${localizations.help}?',
              style: const TextStyle(fontWeight: FontWeight.bold),
              recognizer: TapGestureRecognizer()
                ..onTap = () {
                  launchUrl(Uri.parse('${baseUrl}support/'));
                },
            ),
          ],
        ),
      ),
    );
  }
}
