// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Patrick Zwick

import 'package:country_picker/country_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../messages/app_localizations.dart';
import '../../model/data.dart';
import '../../model/entry_check.dart';
import '../../model/result.dart';
import '../../model/trip.dart';
import '../../service/services.dart';
import '../../util/country_data.dart';
import '../../util/country_name.dart';
import '../shared/status_row.dart';

class EntryCheckPage extends StatefulWidget {
  final List<Data> data;
  final Trip trip;

  const EntryCheckPage({required this.data, required this.trip, super.key});

  @override
  State<EntryCheckPage> createState() => _EntryCheckPageState();
}

class _EntryCheckPageState extends State<EntryCheckPage> {
  bool _loading = false;
  EntryCheck? _entryCheck;
  EntryCheckResult? _result;
  Failure<EntryCheck>? _failure;
  Map<String, String> _translations = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _check());
  }

  Future<void> _check() async {
    final trip = widget.trip;
    final countryCode = iso2ToIso3[trip.countryCode];

    if (countryCode == null) {
      return;
    }

    final locale = Localizations.localeOf(context).languageCode;

    setState(() {
      _loading = true;
      _entryCheck = null;
      _result = null;
      _failure = null;
    });

    final entryCheckResult = await entryCheckService.getEntryCheck(countryCode);

    if (!mounted) {
      return;
    }

    if (entryCheckResult is! Success<EntryCheck>) {
      setState(() {
        _loading = false;
        _failure = entryCheckResult as Failure<EntryCheck>;
      });

      return;
    }

    final entryCheck = entryCheckResult.value!;
    final translations = locale == 'de' ? <String, String>{} : await _translate(entryCheck, locale);

    if (!mounted) {
      return;
    }

    setState(() {
      _loading = false;
      _entryCheck = entryCheck;
      _result = entryCheckService.evaluate(entryCheck, widget.data, trip.start, trip.end);
      _translations = translations;
    });
  }

  Future<Map<String, String>> _translate(EntryCheck entryCheck, String locale) async {
    final texts = {
      ?entryCheck.visaNote,
      for (final form in entryCheck.forms) ...[form.name, ?form.note],
      for (final fee in entryCheck.fees) fee.name,
    }.toList();

    if (texts.isEmpty || !await translationService.ensureModels('de', locale)) {
      return {};
    }

    final translated = await translationService.translateList(texts, from: 'de', to: locale);

    if (translated == null) {
      return {};
    }

    return Map.fromIterables(texts, translated);
  }

  String _text(String german) => _translations[german] ?? german;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final mutedColor = theme.colorScheme.onSurface.withValues(alpha: 0.5);

    return Scaffold(
      appBar: AppBar(title: Text(localizations.entryCheckTitle)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
        children: [
          Text(localizations.entryCheckSubtitle, style: theme.textTheme.bodyMedium),
          const SizedBox(height: 16),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Text(Country.tryParse(widget.trip.countryCode)?.flagEmoji ?? '', style: const TextStyle(fontSize: 28)),
            title: Text(tripCountryName(context, widget.trip), style: theme.textTheme.titleMedium),
            subtitle: Text(_formatRange(DateTimeRange(start: widget.trip.start, end: widget.trip.end))),
          ),
          const SizedBox(height: 8),
          if (_loading) LoadingRow(text: localizations.entryCheckLoading),
          if (iso2ToIso3[widget.trip.countryCode] == null)
            StatusRow(icon: Icons.info_outline, color: mutedColor, text: localizations.countryNoInformation),
          if (_failure != null)
            StatusRow(
              icon: _failure is NetworkFailure ? Icons.wifi_off_outlined : Icons.info_outline,
              color: mutedColor,
              text: _failure!.localizedMessage(localizations),
            ),
          if (_entryCheck != null && _result != null) ..._buildResults(localizations, theme, _entryCheck!, _result!),
        ],
      ),
    );
  }

  List<Widget> _buildResults(
    AppLocalizations localizations,
    ThemeData theme,
    EntryCheck entryCheck,
    EntryCheckResult result,
  ) {
    final dateFormat = DateFormat.yMd(localizations.localeName);

    return [
      _Section(title: localizations.entryCheckSectionPassport),
      switch (result.passportStatus) {
        PassportStatus.missing => _ResultRow.warning(localizations.entryCheckPassportMissing),
        PassportStatus.noExpiryDate => _ResultRow.warning(localizations.entryCheckPassportNoExpiry),
        PassportStatus.expiresTooSoon => _ResultRow.problem(
          localizations.entryCheckPassportTooShort(
            dateFormat.format(result.passportExpiryDate!),
            dateFormat.format(result.passportRequiredUntil!),
          ),
        ),
        PassportStatus.valid => _ResultRow.ok(
          localizations.entryCheckPassportValid(
            dateFormat.format(result.passportExpiryDate!),
            dateFormat.format(result.passportRequiredUntil!),
          ),
        ),
      },
      _Section(title: localizations.entryCheckSectionVisa),
      switch (result.visaStatus) {
        VisaStatus.notRequired => _ResultRow.ok(localizations.entryCheckVisaNotRequired),
        VisaStatus.visaFree => _ResultRow.ok(
          localizations.entryCheckVisaFree(entryCheck.visaFreeDays!, result.tripDays),
        ),
        VisaStatus.stayTooLong => _ResultRow.problem(
          localizations.entryCheckVisaTooLong(entryCheck.visaFreeDays!, result.tripDays),
        ),
        VisaStatus.unknown => _ResultRow.warning(localizations.entryCheckVisaUnknown),
      },
      if (entryCheck.visaNote != null) _ResultRow.info(_text(entryCheck.visaNote!)),
      if (entryCheck.forms.isNotEmpty) ...[
        _Section(title: localizations.entryCheckSectionForms),
        for (final form in entryCheck.forms)
          _ResultRow(
            icon: form.mandatory ? Icons.assignment_late_outlined : Icons.assignment_outlined,
            color: form.mandatory ? Colors.orange.shade700 : theme.colorScheme.onSurface.withValues(alpha: 0.5),
            title:
                '${_text(form.name)} (${form.mandatory ? localizations.entryCheckFormMandatory : localizations.entryCheckFormOptional})',
            subtitle: form.note == null ? null : _text(form.note!),
            url: form.url,
          ),
      ],
      if (entryCheck.fees.isNotEmpty) ...[
        _Section(title: localizations.entryCheckSectionFees),
        for (final fee in entryCheck.fees)
          _ResultRow(
            icon: Icons.payments_outlined,
            color: theme.colorScheme.primary,
            title: '${_text(fee.name)}: ${fee.amount}',
            url: fee.url,
          ),
      ],
      if (result.vaccines.isNotEmpty) ...[
        _Section(title: localizations.entryCheckSectionVaccines),
        for (final vaccine in result.vaccines) _buildVaccineRow(localizations, vaccine),
      ],
      if (result.vaccinationPlan.isNotEmpty) ...[
        _Section(title: localizations.entryCheckSectionPlan),
        for (final step in result.vaccinationPlan) _buildPlanRow(localizations, dateFormat, step),
        Text(localizations.entryCheckPlanNote, style: theme.textTheme.bodySmall),
        if (_nextReminderDate(result.vaccinationPlan) != null) ...[
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => _remind(localizations, dateFormat, entryCheck, result.vaccinationPlan),
            icon: const Icon(Icons.notifications_outlined, size: 16),
            label: Text(localizations.entryCheckPlanRemind),
          ),
        ],
      ],
      const SizedBox(height: 24),
      Text(switch (entryCheck.source) {
        EntrySource.foreignOffice => localizations.entryCheckSource(dateFormat.format(entryCheck.sourceUpdatedAt)),
        EntrySource.passportAct => localizations.entryCheckSourcePassportAct(
          dateFormat.format(entryCheck.sourceUpdatedAt),
        ),
      }, style: theme.textTheme.bodySmall),
      const SizedBox(height: 4),
      Text(switch (entryCheck.source) {
        EntrySource.foreignOffice => localizations.entryCheckDisclaimer,
        EntrySource.passportAct => localizations.entryCheckDisclaimerPassportAct,
      }, style: theme.textTheme.bodySmall),
      const SizedBox(height: 12),
      OutlinedButton.icon(
        onPressed: () => launchUrl(Uri.parse(entryCheck.sourceUrl), mode: LaunchMode.externalApplication),
        icon: const Icon(Icons.open_in_new, size: 16),
        label: Text(switch (entryCheck.source) {
          EntrySource.foreignOffice => localizations.entryCheckOpenSource,
          EntrySource.passportAct => localizations.entryCheckOpenPassportAct,
        }),
      ),
    ];
  }

  Widget _buildVaccineRow(AppLocalizations localizations, VaccineResult vaccine) {
    final requirement = vaccine.onlyWhenArrivingFromRiskArea
        ? localizations.entryCheckVaccineRequiredFromRiskArea
        : vaccine.required
        ? localizations.entryCheckVaccineRequired
        : localizations.entryCheckVaccineRecommended;

    final status = switch (vaccine.status) {
      VaccineStatus.recorded => localizations.entryCheckVaccineRecorded,
      VaccineStatus.boosterDue => localizations.entryCheckVaccineBoosterDue,
      VaccineStatus.missing => localizations.entryCheckVaccineMissing,
    };

    final title = '${_diseaseName(localizations, vaccine.disease)}: $status';

    if (vaccine.status == VaccineStatus.recorded) {
      return _ResultRow.ok(title, subtitle: requirement);
    }

    if (vaccine.required && !vaccine.onlyWhenArrivingFromRiskArea) {
      return _ResultRow.problem(title, subtitle: requirement);
    }

    return _ResultRow.warning(title, subtitle: requirement);
  }

  Widget _buildPlanRow(AppLocalizations localizations, DateFormat dateFormat, VaccinationStep step) {
    final title = _diseaseName(localizations, step.disease);
    final startBy = step.startBy;

    if (step.leadDays == null) {
      return _ResultRow.warning(title, subtitle: localizations.entryCheckPlanAskEarly);
    }

    if (startBy == null) {
      return _ResultRow.warning(title, subtitle: localizations.entryCheckPlanAsap);
    }

    if (startBy.isBefore(_today())) {
      return _ResultRow.problem(title, subtitle: localizations.entryCheckPlanTooLate);
    }

    return _ResultRow.warning(title, subtitle: localizations.entryCheckPlanStartBy(dateFormat.format(startBy)));
  }

  DateTime _today() {
    final now = DateTime.now();

    return DateTime(now.year, now.month, now.day);
  }

  DateTime? _nextReminderDate(List<VaccinationStep> plan) {
    final tomorrow = _today().add(const Duration(days: 1));
    final startDates = plan.map((step) => step.startBy).whereType<DateTime>().where((date) => !date.isBefore(tomorrow));

    if (startDates.isEmpty) {
      return null;
    }

    final reminderDate = startDates
        .reduce((earliest, date) => date.isBefore(earliest) ? date : earliest)
        .subtract(const Duration(days: 7));

    return reminderDate.isBefore(tomorrow) ? tomorrow : reminderDate;
  }

  Future<void> _remind(
    AppLocalizations localizations,
    DateFormat dateFormat,
    EntryCheck entryCheck,
    List<VaccinationStep> plan,
  ) async {
    final reminderDate = _nextReminderDate(plan)!;

    final scheduled = await notificationService.scheduleVaccinationReminder(
      reminderDate,
      localizations.entryCheckPlanReminderTitle(tripCountryName(context, widget.trip)),
      localizations.entryCheckPlanReminderBody,
    );

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          scheduled
              ? localizations.entryCheckPlanReminderSet(dateFormat.format(reminderDate))
              : localizations.settingsNotificationPermissionDenied,
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  String _diseaseName(AppLocalizations localizations, String disease) => switch (disease) {
    'YELLOW_FEVER' => localizations.entryCheckDiseaseYellowFever,
    'HEPATITIS_A' => localizations.entryCheckDiseaseHepatitisA,
    'HEPATITIS_B' => localizations.entryCheckDiseaseHepatitisB,
    'TYPHOID' => localizations.entryCheckDiseaseTyphoid,
    'RABIES' => localizations.entryCheckDiseaseRabies,
    'JAPANESE_ENCEPHALITIS' => localizations.entryCheckDiseaseJapaneseEncephalitis,
    'POLIO' => localizations.entryCheckDiseasePolio,
    'MEASLES' => localizations.entryCheckDiseaseMeasles,
    'CHOLERA' => localizations.entryCheckDiseaseCholera,
    'MENINGOCOCCAL' => localizations.entryCheckDiseaseMeningococcal,
    'DENGUE' => localizations.entryCheckDiseaseDengue,
    'CHIKUNGUNYA' => localizations.entryCheckDiseaseChikungunya,
    'TICK_BORNE_ENCEPHALITIS' => localizations.entryCheckDiseaseTickBorneEncephalitis,
    'INFLUENZA' => localizations.entryCheckDiseaseInfluenza,
    _ => disease,
  };

  String _formatRange(DateTimeRange range) {
    final dateFormat = DateFormat.yMd(AppLocalizations.of(context)!.localeName);

    return '${dateFormat.format(range.start)} - ${dateFormat.format(range.end)}';
  }
}

class _Section extends StatelessWidget {
  final String title;

  const _Section({required this.title});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 8),
      child: Text(
        title,
        style: theme.textTheme.labelMedium?.copyWith(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _ResultRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String? subtitle;
  final String? url;

  const _ResultRow({required this.icon, required this.color, required this.title, this.subtitle, this.url});

  _ResultRow.ok(this.title, {this.subtitle})
    : icon = Icons.check_circle_outline,
      color = Colors.green.shade600,
      url = null;

  _ResultRow.warning(this.title, {this.subtitle})
    : icon = Icons.info_outline,
      color = Colors.orange.shade700,
      url = null;

  _ResultRow.problem(this.title, {this.subtitle}) : icon = Icons.error_outline, color = Colors.red.shade600, url = null;

  const _ResultRow.info(this.title) : icon = Icons.notes_outlined, color = Colors.grey, subtitle = null, url = null;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final link = url;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: link == null ? null : () => launchUrl(Uri.parse(link), mode: LaunchMode.externalApplication),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: theme.textTheme.bodyMedium),
                  if (subtitle != null) Text(subtitle!, style: theme.textTheme.bodySmall),
                ],
              ),
            ),
            if (link != null) Icon(Icons.open_in_new, size: 16, color: theme.colorScheme.primary),
          ],
        ),
      ),
    );
  }
}
