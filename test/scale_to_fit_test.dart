// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Patrick Zwick

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:journai_app/messages/app_localizations.dart';
import 'package:journai_app/model/emergency/emergency_card_content.dart';
import 'package:journai_app/widget/shared/emergency_card_view.dart';
import 'package:journai_app/widget/shared/scale_to_fit.dart';

void main() {
  final localizations = lookupAppLocalizations(const Locale('en'));

  Future<void> pumpCard(WidgetTester tester, Size size, List<String> allergies) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: size.width,
            height: size.height,
            child: ScaleToFit(
              child: EmergencyCardView(
                localizations: localizations,
                content: EmergencyCardContent(
                  allergies: allergies,
                  conditions: const ['Asthma'],
                  vitalSigns: const ['Blood type A+'],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  for (final size in const [Size(360, 380), Size(276, 310), Size(380, 180), Size(180, 500)]) {
    for (final allergies in [
      const ['Penicillin'],
      List.generate(30, (index) => 'Allergy number $index'),
    ]) {
      testWidgets('card fills $size with ${allergies.length} allergies', (tester) async {
        await pumpCard(tester, size, allergies);

        final cardRect = tester.getRect(find.byType(EmergencyCardView));

        expect(cardRect.topLeft.dx.abs(), lessThan(0.5));
        expect(cardRect.topLeft.dy.abs(), lessThan(0.5));
        expect(cardRect.right, lessThanOrEqualTo(size.width + 0.5));
        expect(cardRect.bottom, lessThanOrEqualTo(size.height + 0.5));
        expect(cardRect.width > size.width * 0.95 || cardRect.height > size.height * 0.95, isTrue);
      });
    }
  }

  testWidgets('short content is scaled up in a large widget', (tester) async {
    tester.view.physicalSize = const Size(1600, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await pumpCard(tester, const Size(720, 760), const ['Penicillin']);

    expect(tester.getRect(find.text(localizations.dashboardEmergencyCardTitle)).height, greaterThan(30));
  });
}
