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

  testWidgets('paid users cannot buy another paid plan', (tester) async {
    await tester.pumpWidget(app('PRO'));
    await tester.pump();

    final buttons = tester.widgetList<FilledButton>(find.byType(FilledButton)).toList();

    expect(buttons, isNotEmpty);
    expect(buttons.every((button) => button.onPressed == null), isTrue);
  });

  testWidgets('free users can buy paid plans', (tester) async {
    await tester.pumpWidget(app('FREE'));
    await tester.pump();

    final buttons = tester.widgetList<FilledButton>(find.byType(FilledButton)).toList();

    expect(buttons.length, 2);
    expect(buttons.every((button) => button.onPressed != null), isTrue);
  });
}
