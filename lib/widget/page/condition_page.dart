// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Patrick Zwick

import 'package:flutter/material.dart';

import '../../messages/app_localizations.dart';
import '../shared/document_list_page.dart';
import '../shared/document_shared.dart';
import '../shared/form_sheet.dart';
import '../shared/predefined_name_field.dart';

class ConditionPage extends StatelessWidget {
  const ConditionPage({super.key});

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;

    return DocumentListPage(
      feature: 'CONDITION',
      title: localizations.conditionTitle,
      emptyText: localizations.conditionEmpty,
      deleteConfirmText: (localizations) => localizations.conditionDeleteConfirm,
      icon: Icons.medical_information_outlined,
      summarize: (fields, localizations) => (
        fields['name'] as String? ?? '',
        [
          if (fields['diagnosedDate'] case final String diagnosedDate) (localizations.conditionDiagnosedDate, diagnosedDate),
        ],
      ),
      formBuilder: (initialFields) => _ConditionFormSheet(initialFields: initialFields),
    );
  }
}

class _ConditionFormSheet extends StatefulWidget {
  final Map<String, dynamic>? initialFields;

  const _ConditionFormSheet({this.initialFields});

  @override
  State<_ConditionFormSheet> createState() => _ConditionFormSheetState();
}

class _ConditionFormSheetState extends State<_ConditionFormSheet> {
  late final TextEditingController _nameController;
  late final TextEditingController _diagnosedDateController;
  late final TextEditingController _notesController;
  bool _submitted = false;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialFields ?? {};
    _nameController = TextEditingController(
      text: initial['name'] as String? ?? '',
    );
    _diagnosedDateController = TextEditingController(
      text: initial['diagnosedDate'] as String? ?? '',
    );
    _notesController = TextEditingController(
      text: initial['notes'] as String? ?? '',
    );
  }

  List<String> _conditionList(AppLocalizations localizations) => [
    localizations.conditionPredefinedAsthma,
    localizations.conditionPredefinedDiabetesType1,
    localizations.conditionPredefinedDiabetesType2,
    localizations.conditionPredefinedHypertension,
    localizations.conditionPredefinedCoronaryArteryDisease,
    localizations.conditionPredefinedHeartFailure,
    localizations.conditionPredefinedAtrialFibrillation,
    localizations.conditionPredefinedHypothyroidism,
    localizations.conditionPredefinedHyperthyroidism,
    localizations.conditionPredefinedEpilepsy,
    localizations.conditionPredefinedDepression,
    localizations.conditionPredefinedAnxietyDisorder,
    localizations.conditionPredefinedAdhd,
    localizations.conditionPredefinedCeliacDisease,
    localizations.conditionPredefinedCrohnsDisease,
    localizations.conditionPredefinedUlcerativeColitis,
    localizations.conditionPredefinedRheumatoidArthritis,
    localizations.conditionPredefinedOsteoporosis,
    localizations.conditionPredefinedPsoriasis,
    localizations.conditionPredefinedMultipleSclerosis,
    localizations.conditionPredefinedParkinsonsDisease,
    localizations.conditionPredefinedCopd,
    localizations.conditionPredefinedSleepApnea,
    localizations.conditionPredefinedMigraine,
    localizations.conditionPredefinedKidneyDisease,
    localizations.conditionPredefinedLiverDisease,
    localizations.conditionPredefinedCancer,
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _diagnosedDateController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _submit() {
    setState(() => _submitted = true);

    final name = _nameController.text.trim();

    if (name.isEmpty) {
      return;
    }

    final fields = {
      'name': name,
      if (_diagnosedDateController.text.trim().isNotEmpty)
        'diagnosedDate': _diagnosedDateController.text.trim(),
      if (_notesController.text.trim().isNotEmpty)
        'notes': _notesController.text.trim(),
    };

    Navigator.of(context).pop(fields);
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final isEditing = widget.initialFields != null;
    final nameError = _submitted && _nameController.text.trim().isEmpty
        ? localizations.conditionNameRequired
        : null;
    final conditionList = _conditionList(localizations);

    return FormSheet(
      title: isEditing ? localizations.conditionEditTitle : localizations.conditionManualTitle,
      onSave: _submit,
      children: [
        PredefinedNameField(
          controller: _nameController,
          names: conditionList,
          selectLabel: localizations.conditionSelectFromList,
          nameLabel: localizations.conditionNameHint,
          errorText: nameError,
        ),
        const SizedBox(height: 12),
        DatePickerField(
          controller: _diagnosedDateController,
          labelText: localizations.conditionDiagnosedDateHint,
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _notesController,
          decoration: InputDecoration(labelText: localizations.documentNotesHint),
          maxLines: 2,
        ),
      ],
    );
  }
}
