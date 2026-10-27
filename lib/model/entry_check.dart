// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Patrick Zwick

class EntryCheck {
  final String countryCode;
  final String countryName;
  final String sourceUrl;
  final DateTime sourceUpdatedAt;
  final EntrySource source;
  final int? passportValidityMonths;
  final int? visaFreeDays;
  final String? visaNote;
  final bool unlimitedStay;
  final List<EntryForm> forms;
  final List<EntryFee> fees;
  final List<RequiredVaccine> requiredVaccines;
  final List<String> recommendedVaccines;

  const EntryCheck({
    required this.countryCode,
    required this.countryName,
    required this.sourceUrl,
    required this.sourceUpdatedAt,
    this.source = EntrySource.foreignOffice,
    this.passportValidityMonths,
    this.visaFreeDays,
    this.visaNote,
    this.unlimitedStay = false,
    this.forms = const [],
    this.fees = const [],
    this.requiredVaccines = const [],
    this.recommendedVaccines = const [],
  });

  factory EntryCheck.fromJson(Map<String, dynamic> json) {
    final requirements = json['requirements'] as Map<String, dynamic>? ?? {};

    return EntryCheck(
      countryCode: json['countryCode'] as String,
      countryName: json['countryName'] as String,
      sourceUrl: json['sourceUrl'] as String,
      sourceUpdatedAt: DateTime.fromMillisecondsSinceEpoch((json['sourceUpdatedAt'] as int) * 1000),
      source: json['source'] == 'PASSPORT_ACT' ? EntrySource.passportAct : EntrySource.foreignOffice,
      passportValidityMonths: requirements['passportValidityMonths'] as int?,
      visaFreeDays: requirements['visaFreeDays'] as int?,
      visaNote: requirements['visaNote'] as String?,
      unlimitedStay: requirements['unlimitedStay'] as bool? ?? false,
      forms: [
        for (final form in requirements['forms'] as List? ?? [])
          EntryForm(
            name: form['name'] as String,
            url: form['url'] as String?,
            note: form['note'] as String?,
            mandatory: form['mandatory'] as bool? ?? false,
          ),
      ],
      fees: [
        for (final fee in requirements['fees'] as List? ?? [])
          EntryFee(name: fee['name'] as String, amount: fee['amount'] as String, url: fee['url'] as String?),
      ],
      requiredVaccines: [
        for (final vaccine in requirements['requiredVaccines'] as List? ?? [])
          RequiredVaccine(
            disease: vaccine['disease'] as String,
            onlyWhenArrivingFromRiskArea: vaccine['onlyWhenArrivingFromRiskArea'] as bool? ?? false,
          ),
      ],
      recommendedVaccines: List<String>.from(requirements['recommendedVaccines'] as List? ?? []),
    );
  }
}

class EntryForm {
  final String name;
  final String? url;
  final String? note;
  final bool mandatory;

  const EntryForm({required this.name, this.url, this.note, this.mandatory = false});
}

class EntryFee {
  final String name;
  final String amount;
  final String? url;

  const EntryFee({required this.name, required this.amount, this.url});
}

class RequiredVaccine {
  final String disease;
  final bool onlyWhenArrivingFromRiskArea;

  const RequiredVaccine({required this.disease, this.onlyWhenArrivingFromRiskArea = false});
}

enum PassportStatus { missing, noExpiryDate, valid, expiresTooSoon }

enum EntrySource { foreignOffice, passportAct }

enum VisaStatus { notRequired, visaFree, stayTooLong, unknown }

enum VaccineStatus { recorded, boosterDue, missing }

class VaccineResult {
  final String disease;
  final bool required;
  final bool onlyWhenArrivingFromRiskArea;
  final VaccineStatus status;

  const VaccineResult({
    required this.disease,
    required this.required,
    required this.onlyWhenArrivingFromRiskArea,
    required this.status,
  });
}

class VaccinationStep {
  final String disease;
  final int? leadDays;
  final DateTime? startBy;

  const VaccinationStep({required this.disease, this.leadDays, this.startBy});
}

class EntryCheckResult {
  final PassportStatus passportStatus;
  final DateTime? passportExpiryDate;
  final DateTime? passportRequiredUntil;
  final VisaStatus visaStatus;
  final int tripDays;
  final List<VaccineResult> vaccines;
  final List<VaccinationStep> vaccinationPlan;

  const EntryCheckResult({
    required this.passportStatus,
    required this.passportExpiryDate,
    required this.passportRequiredUntil,
    required this.visaStatus,
    required this.tripDays,
    required this.vaccines,
    this.vaccinationPlan = const [],
  });
}
