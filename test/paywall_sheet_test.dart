// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Patrick Zwick

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:journai_app/messages/app_localizations.dart';
import 'package:journai_app/widget/sheet/paywall_sheet.dart';

void main() {
  Widget app(String currentTier) => MaterialApp(
    locale: const Locale('en'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: PaywallSheet(currentTier: currentTier)),
  );

  testWidgets('paid users can manage or cancel their subscription', (tester) async {
    await tester.pumpWidget(app('PRO'));
    await tester.pump();

    expect(find.byKey(const ValueKey('subscription_manage')), findsOneWidget);
    expect(find.text('Manage or cancel subscription'), findsOneWidget);
  });

  testWidgets('free users see no subscription management', (tester) async {
    await tester.pumpWidget(app('FREE'));
    await tester.pump();

    expect(find.byKey(const ValueKey('subscription_manage')), findsNothing);
  });
}
