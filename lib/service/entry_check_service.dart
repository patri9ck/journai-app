// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Patrick Zwick

import '../model/data.dart';
import '../model/entry_check.dart';
import '../model/result.dart';
import '../util/cache.dart';
import '../util/document_date.dart';
import 'request_service.dart';

class EntryCheckService {
  static const _vaccineKeywords = {
    'YELLOW_FEVER': ['gelbfieber', 'yellow fever', 'fièvre jaune', 'fiebre amarilla', 'febbre gialla', 'żółta gorączka', 'sarı humma', 'желтая лихорадка', 'жовта гарячка', 'الحمى الصفراء', '黄熱', '黄热', 'stamaril'],
    'HEPATITIS_A': ['hepatitis a', 'hépatite a', 'epatite a', 'wzw a', 'hepatit a', 'гепатит a', 'гепатит а', 'التهاب الكبد أ', 'a型肝炎', '甲型肝炎', 'havrix', 'vaqta', 'avaxim', 'twinrix', 'vivaxim'],
    'HEPATITIS_B': ['hepatitis b', 'hépatite b', 'epatite b', 'wzw b', 'hepatit b', 'гепатит b', 'гепатит в', 'التهاب الكبد ب', 'b型肝炎', '乙型肝炎', 'engerix', 'hbvaxpro', 'heplisav', 'twinrix'],
    'TYPHOID': ['typhus', 'typhoid', 'typhoïde', 'tifoidea', 'febbre tifoide', 'dur brzuszny', 'tifo', 'брюшной тиф', 'черевний тиф', 'التيفوئيد', '腸チフス', '伤寒', 'typhim', 'typhoral', 'vivotif'],
    'RABIES': ['tollwut', 'rabies', 'rage', 'rabia', 'wścieklizn', 'kuduz', 'бешенств', 'сказ', 'داء الكلب', '狂犬', 'rabipur', 'verorab'],
    'JAPANESE_ENCEPHALITIS': ['japanische enzephalitis', 'japanese encephalitis', 'encéphalite japonaise', 'encefalitis japonesa', 'encefalite giapponese', 'japońskie zapalenie', 'japon ensefaliti', 'японский энцефалит', 'японський енцефаліт', 'التهاب الدماغ الياباني', '日本脳炎', '乙型脑炎', 'ixiaro'],
    'POLIO': ['polio', 'poliomyelitis', 'poliomyélite', 'poliomielitis', 'poliomielite', 'полиомиелит', 'поліомієліт', 'شلل الأطفال', 'ポリオ', '脊髓灰质炎', 'repevax', 'revaxis'],
    'MEASLES': ['masern', 'measles', 'rougeole', 'sarampión', 'morbillo', 'odra', 'kızamık', 'корь', 'кір', 'الحصبة', '麻疹', 'mmr', 'priorix'],
    'CHOLERA': ['cholera', 'choléra', 'cólera', 'kolera', 'холера', 'الكوليرا', 'コレラ', '霍乱', 'dukoral', 'vaxchora'],
    'MENINGOCOCCAL': ['meningokok', 'meningococ', 'méningocoque', 'менингокок', 'менінгокок', 'المكورات السحائية', '髄膜炎菌', '脑膜炎球菌', 'menveo', 'nimenrix', 'bexsero', 'trumenba'],
    'DENGUE': ['dengue', 'денге', 'حمى الضنك', 'デング', '登革热', 'qdenga'],
    'CHIKUNGUNYA': ['chikungunya', 'чикунгунья', 'شيكونغونيا', 'チクングニア', '基孔肯雅', 'ixchiq', 'vimkunya'],
    'TICK_BORNE_ENCEPHALITIS': ['fsme', 'tick-borne', 'encéphalite à tiques', 'encefalitis transmitida por garrapatas', 'encefalite da zecche', 'kleszczowe', 'kene kaynaklı', 'клещевой энцефалит', 'кліщовий енцефаліт', 'ダニ媒介', '蜱传', 'encepur'],
    'INFLUENZA': ['influenza', 'grippe', 'flu', 'gripe', 'grypa', 'grip', 'грипп', 'грип', 'الإنفلونزا', 'インフルエンザ', '流感'],
  };

  static const _vaccinationLeadDays = {
    'YELLOW_FEVER': 10,
    'RABIES': 7,
    'JAPANESE_ENCEPHALITIS': 14,
    'TYPHOID': 14,
    'CHOLERA': 10,
    'MENINGOCOCCAL': 10,
    'MEASLES': 42,
    'HEPATITIS_B': 21,
    'DENGUE': 90,
    'HEPATITIS_A': 0,
  };

  final RequestService _requestService;

  EntryCheckService({required RequestService requestService}) : _requestService = requestService;

  Future<Result<EntryCheck>> getEntryCheck(String countryCode) async {
    final cacheKey = 'cache_entry_check_$countryCode';
    final result = await _requestService.getAuthenticatedRequest('entry-check/$countryCode');

    if (result is Success<Map<String, dynamic>>) {
      await saveObjectCache(cacheKey, result.value!);

      return Success(EntryCheck.fromJson(result.value!));
    }

    final cached = await readObjectCache(cacheKey);

    if (result is NetworkFailure && cached != null) {
      return Success(EntryCheck.fromJson(cached));
    }

    return mapResult(result, EntryCheck.fromJson);
  }

  EntryCheckResult evaluate(EntryCheck entryCheck, List<Data> data, DateTime start, DateTime end) {
    final passportExpiryDates = data
        .where((item) => item.feature == 'PASSPORT')
        .map((item) => parseDocumentDate(item.fields['expiryDate'] as String?))
        .toList();

    final latestExpiryDate = passportExpiryDates.whereType<DateTime>().fold<DateTime?>(
      null,
      (latest, date) => latest == null || date.isAfter(latest) ? date : latest,
    );

    final months = entryCheck.passportValidityMonths ?? 0;
    final validAfterEntry = DateTime(start.year, start.month + months, start.day);
    final requiredUntil = validAfterEntry.isAfter(end) ? validAfterEntry : end;

    final passportStatus = switch (latestExpiryDate) {
      _ when passportExpiryDates.isEmpty => PassportStatus.missing,
      null => PassportStatus.noExpiryDate,
      final expiryDate when expiryDate.isBefore(requiredUntil) => PassportStatus.expiresTooSoon,
      _ => PassportStatus.valid,
    };

    final tripDays = DateTime(end.year, end.month, end.day).difference(DateTime(start.year, start.month, start.day)).inDays + 1;
    final visaFreeDays = entryCheck.visaFreeDays;

    final visaStatus = switch (visaFreeDays) {
      _ when entryCheck.unlimitedStay => VisaStatus.notRequired,
      null => VisaStatus.unknown,
      _ when tripDays > visaFreeDays => VisaStatus.stayTooLong,
      _ => VisaStatus.visaFree,
    };

    final vaccineRecords = data.where((item) => item.feature == 'VACCINE').toList();

    final vaccines = [
      for (final vaccine in entryCheck.requiredVaccines)
        VaccineResult(
          disease: vaccine.disease,
          required: true,
          onlyWhenArrivingFromRiskArea: vaccine.onlyWhenArrivingFromRiskArea,
          status: _vaccineStatus(vaccine.disease, vaccineRecords, start),
        ),
      for (final disease in entryCheck.recommendedVaccines)
        if (!entryCheck.requiredVaccines.any((vaccine) => vaccine.disease == disease))
          VaccineResult(
            disease: disease,
            required: false,
            onlyWhenArrivingFromRiskArea: false,
            status: _vaccineStatus(disease, vaccineRecords, start),
          ),
    ];

    return EntryCheckResult(
      passportStatus: passportStatus,
      passportExpiryDate: latestExpiryDate,
      passportRequiredUntil: requiredUntil,
      visaStatus: visaStatus,
      tripDays: tripDays,
      vaccines: vaccines,
      vaccinationPlan: [
        for (final vaccine in vaccines)
          if (vaccine.status != VaccineStatus.recorded) _planVaccination(vaccine.disease, start),
      ],
    );
  }

  VaccinationStep _planVaccination(String disease, DateTime start) {
    final leadDays = _vaccinationLeadDays[disease];

    if (leadDays == null || leadDays == 0) {
      return VaccinationStep(disease: disease, leadDays: leadDays);
    }

    final startDay = DateTime(start.year, start.month, start.day);

    return VaccinationStep(disease: disease, leadDays: leadDays, startBy: startDay.subtract(Duration(days: leadDays)));
  }

  VaccineStatus _vaccineStatus(String disease, List<Data> vaccineRecords, DateTime start) {
    final keywords = _vaccineKeywords[disease] ?? [];

    final matchingRecords = vaccineRecords.where((record) {
      final text = '${record.fields['name'] ?? ''} ${record.fields['disease'] ?? ''}'.toLowerCase();

      return keywords.any(text.contains);
    }).toList();

    if (matchingRecords.isEmpty) {
      return VaccineStatus.missing;
    }

    final hasValidRecord = matchingRecords.any((record) {
      final nextDate = parseDocumentDate(record.fields['nextDate'] as String?);

      return nextDate == null || !nextDate.isBefore(start);
    });

    return hasValidRecord ? VaccineStatus.recorded : VaccineStatus.boosterDue;
  }
}
