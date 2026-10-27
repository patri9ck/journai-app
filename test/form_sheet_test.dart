// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Patrick Zwick

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:journai_app/messages/app_localizations.dart';
import 'package:journai_app/widget/shared/form_sheet.dart';
import 'package:journai_app/widget/shared/predefined_name_field.dart';

void main() {
  Widget app(Widget child) => MaterialApp(
    locale: const Locale('en'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: child),
  );

  testWidgets('choosing a predefined name fills the field and hides the custom input', (tester) async {
    final controller = TextEditingController();

    await tester.pumpWidget(
      app(
        PredefinedNameField(
          controller: controller,
          names: const ['Peanuts', 'Milk'],
          selectLabel: 'Pick',
          nameLabel: 'Name',
        ),
      ),
    );

    expect(find.byType(TextField), findsNothing);

    await tester.tap(find.text('Milk'));
    await tester.pump();

    expect(controller.text, 'Milk');

    final localizations = await AppLocalizations.delegate.load(const Locale('en'));

    await tester.tap(find.text(localizations.customName));
    await tester.pump();

    expect(controller.text, isEmpty);
    expect(find.byType(TextField), findsOneWidget);
  });

  testWidgets('a name outside the list opens the custom input and errors are shown', (tester) async {
    final controller = TextEditingController(text: 'Kiwi');

    await tester.pumpWidget(
      app(
        PredefinedNameField(
          controller: controller,
          names: const ['Peanuts'],
          selectLabel: 'Pick',
          nameLabel: 'Name',
          errorText: 'Required',
        ),
      ),
    );

    expect(find.widgetWithText(TextField, 'Kiwi'), findsOneWidget);
    expect(find.text('Required'), findsOneWidget);
  });

  testWidgets('form sheets show the save button only when they can save', (tester) async {
    final localizations = await AppLocalizations.delegate.load(const Locale('en'));
    var saved = false;

    await tester.pumpWidget(
      app(FormSheet(title: 'Title', onSave: () => saved = true, children: const [Text('Field')])),
    );

    await tester.tap(find.text(localizations.documentSave));

    expect(saved, isTrue);

    await tester.pumpWidget(app(const FormSheet(title: 'Title', children: [Text('Field')])));

    expect(find.text(localizations.documentSave), findsNothing);
  });
}
