// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Patrick Zwick

import 'package:flutter_test/flutter_test.dart';
import 'package:journai_app/model/data.dart';
import 'package:journai_app/model/entry_check.dart';
import 'package:journai_app/service/entry_check_service.dart';
import 'package:journai_app/service/request_service.dart';

void main() {
  final entryCheckService = EntryCheckService(requestService: RequestService(baseUrl: ''));

  final thailand = EntryCheck(
    countryCode: 'THA',
    countryName: 'Thailand',
    sourceUrl: 'https://www.auswaertiges-amt.de/de/ReiseUndSicherheit/201558',
    sourceUpdatedAt: DateTime(2026, 10, 1),
    passportValidityMonths: 6,
    visaFreeDays: 30,
    requiredVaccines: const [RequiredVaccine(disease: 'YELLOW_FEVER', onlyWhenArrivingFromRiskArea: true)],
    recommendedVaccines: const ['HEPATITIS_A', 'RABIES'],
  );

  final start = DateTime(2026, 12, 1);
  final end = DateTime(2026, 12, 20);

  Data passport(String expiryDate) => Data(feature: 'PASSPORT', fields: {'expiryDate': expiryDate});

  Data vaccine(String name, {String? disease, String? nextDate}) => Data(
    feature: 'VACCINE',
    fields: {'name': name, 'disease': ?disease, 'nextDate': ?nextDate},
  );

  test('passport must be valid for six months after entry', () {
    final tooShort = entryCheckService.evaluate(thailand, [passport('2027-03-01')], start, end);
    final longEnough = entryCheckService.evaluate(thailand, [passport('2027-06-01')], start, end);

    expect(tooShort.passportStatus, PassportStatus.expiresTooSoon);
    expect(tooShort.passportRequiredUntil, DateTime(2027, 6, 1));
    expect(longEnough.passportStatus, PassportStatus.valid);
  });

  test('passport dates entered as dd.MM.yyyy are understood', () {
    final result = entryCheckService.evaluate(thailand, [passport('01.06.2027')], start, end);

    expect(result.passportStatus, PassportStatus.valid);
    expect(result.passportExpiryDate, DateTime(2027, 6, 1));
  });

  test('missing passport and missing expiry date are reported', () {
    expect(entryCheckService.evaluate(thailand, [], start, end).passportStatus, PassportStatus.missing);
    expect(
      entryCheckService.evaluate(thailand, [Data(feature: 'PASSPORT', fields: {})], start, end).passportStatus,
      PassportStatus.noExpiryDate,
    );
  });

  test('stays longer than the visa-free period need a visa', () {
    final shortTrip = entryCheckService.evaluate(thailand, [], start, end);
    final longTrip = entryCheckService.evaluate(thailand, [], start, DateTime(2027, 1, 15));

    expect(shortTrip.tripDays, 20);
    expect(shortTrip.visaStatus, VisaStatus.visaFree);
    expect(longTrip.tripDays, 46);
    expect(longTrip.visaStatus, VisaStatus.stayTooLong);
  });

  test('vaccines are matched by disease or trade name in any language', () {
    final result = entryCheckService.evaluate(
      thailand,
      [vaccine('Havrix 1440'), vaccine('Stamaril', disease: 'Gelbfieber')],
      start,
      end,
    );

    final statuses = {for (final vaccine in result.vaccines) vaccine.disease: vaccine.status};

    expect(statuses['YELLOW_FEVER'], VaccineStatus.recorded);
    expect(statuses['HEPATITIS_A'], VaccineStatus.recorded);
    expect(statuses['RABIES'], VaccineStatus.missing);
    expect(result.vaccines.first.required, isTrue);
    expect(result.vaccines.first.onlyWhenArrivingFromRiskArea, isTrue);
  });

  test('a booster due before the trip is reported', () {
    final result = entryCheckService.evaluate(
      thailand,
      [vaccine('Rabipur', disease: 'Tollwut', nextDate: '2026-11-01')],
      start,
      end,
    );

    final rabies = result.vaccines.firstWhere((vaccine) => vaccine.disease == 'RABIES');

    expect(rabies.status, VaccineStatus.boosterDue);
  });

  test('a trip home from the passport act needs no visa however long it is', () {
    final germany = EntryCheck.fromJson({
      'countryCode': 'DEU',
      'countryName': 'Deutschland',
      'sourceUrl': 'https://www.gesetze-im-internet.de/pa_g_1986/__1.html',
      'sourceUpdatedAt': 1784160000,
      'source': 'PASSPORT_ACT',
      'requirements': {'passportValidityMonths': 0, 'unlimitedStay': true},
    });

    final result = entryCheckService.evaluate(germany, [], start, DateTime(2027, 12, 1));

    expect(germany.source, EntrySource.passportAct);
    expect(result.visaStatus, VisaStatus.notRequired);
    expect(thailand.source, EntrySource.foreignOffice);
  });

  test('entry check json from the server is parsed', () {
    final entryCheck = EntryCheck.fromJson({
      'countryCode': 'IDN',
      'countryName': 'Indonesien',
      'sourceUrl': 'https://www.auswaertiges-amt.de/de/ReiseUndSicherheit/212396',
      'sourceUpdatedAt': 1792067156,
      'requirements': {
        'passportValidityMonths': 6,
        'forms': [
          {'name': 'Digitale Einreisekarte', 'url': 'https://allindonesia.imigrasi.go.id/', 'mandatory': true},
        ],
        'fees': [
          {'name': 'Tourismusgebühr Bali', 'amount': '150.000 IDR'},
        ],
        'recommendedVaccines': ['HEPATITIS_A', 'POLIO'],
      },
    });

    expect(entryCheck.visaFreeDays, isNull);
    expect(entryCheck.forms.single.mandatory, isTrue);
    expect(entryCheck.fees.single.amount, '150.000 IDR');
    expect(entryCheck.recommendedVaccines, ['HEPATITIS_A', 'POLIO']);
  });

  test('vaccination plan lists missing vaccines with the latest start date', () {
    final result = entryCheckService.evaluate(thailand, [vaccine('Havrix')], start, end);
    final plan = {for (final step in result.vaccinationPlan) step.disease: step};

    expect(plan.containsKey('HEPATITIS_A'), isFalse);
    expect(plan['RABIES']!.startBy, DateTime(2026, 11, 24));
    expect(plan['YELLOW_FEVER']!.startBy, DateTime(2026, 11, 21));
  });

  test('vaccination plan gives guidance when there is no fixed lead time', () {
    final japan = EntryCheck(
      countryCode: 'JPN',
      countryName: 'Japan',
      sourceUrl: 'https://www.auswaertiges-amt.de/de/ReiseUndSicherheit/205186',
      sourceUpdatedAt: DateTime(2026, 10, 1),
      recommendedVaccines: const ['HEPATITIS_A', 'TICK_BORNE_ENCEPHALITIS'],
    );

    final plan = {
      for (final step in entryCheckService.evaluate(japan, [], start, end).vaccinationPlan) step.disease: step,
    };

    expect(plan['HEPATITIS_A']!.leadDays, 0);
    expect(plan['HEPATITIS_A']!.startBy, isNull);
    expect(plan['TICK_BORNE_ENCEPHALITIS']!.leadDays, isNull);
  });

  test('a fully vaccinated traveler gets no vaccination plan', () {
    final result = entryCheckService.evaluate(
      thailand,
      [vaccine('Havrix'), vaccine('Rabipur'), vaccine('Stamaril')],
      start,
      end,
    );

    expect(result.vaccinationPlan, isEmpty);
  });
}
