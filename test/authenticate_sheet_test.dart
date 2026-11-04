// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Patrick Zwick

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:journai_app/messages/app_localizations.dart';
import 'package:journai_app/model/auth_mode.dart';
import 'package:journai_app/model/contact/contact_type.dart';
import 'package:journai_app/widget/page/contact_page.dart';
import 'package:journai_app/widget/sheet/login_sheet.dart';
import 'package:journai_app/widget/sheet/register_sheet.dart';

void main() {
  Widget app(Widget home) => MaterialApp(
    locale: const Locale('en'),
    theme: ThemeData(inputDecorationTheme: const InputDecorationTheme(border: OutlineInputBorder())),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: home),
  );

  bool isEnabled(WidgetTester tester, String label) {
    final button = tester.widget<ButtonStyleButton>(
      find.ancestor(of: find.text(label), matching: find.bySubtype<ButtonStyleButton>()),
    );

    return button.onPressed != null;
  }

  testWidgets('registration options unlock once the terms are accepted', (tester) async {
    await tester.pumpWidget(app(const RegisterSheet()));

    final localizations = await AppLocalizations.delegate.load(const Locale('en'));

    expect(isEnabled(tester, localizations.emailAddressRegister), isFalse);
    expect(isEnabled(tester, localizations.phoneNumberRegister), isFalse);
    expect(isEnabled(tester, localizations.googleAccountRegister), isFalse);

    await tester.tap(find.byType(Checkbox));
    await tester.pump();

    expect(isEnabled(tester, localizations.emailAddressRegister), isTrue);
    expect(isEnabled(tester, localizations.phoneNumberRegister), isTrue);
    expect(isEnabled(tester, localizations.googleAccountRegister), isTrue);
  });

  testWidgets('login options are available right away', (tester) async {
    await tester.pumpWidget(app(const LoginSheet()));

    final localizations = await AppLocalizations.delegate.load(const Locale('en'));

    expect(isEnabled(tester, localizations.emailAddressLogin), isTrue);
    expect(isEnabled(tester, localizations.phoneNumberLogin), isTrue);
  });

  testWidgets('the contact page asks for the matching contact type', (tester) async {
    final localizations = await AppLocalizations.delegate.load(const Locale('en'));

    await tester.pumpWidget(app(const ContactPage(type: ContactType.email, mode: AuthMode.login)));

    expect(find.text(localizations.requestEmail), findsOneWidget);
    expect(find.byIcon(Icons.email_outlined), findsOneWidget);

    await tester.pumpWidget(app(const ContactPage(type: ContactType.phone, mode: AuthMode.register)));

    expect(find.text(localizations.requestSms), findsOneWidget);
    expect(find.byIcon(Icons.sms_outlined), findsOneWidget);
  });
}
