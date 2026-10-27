// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Patrick Zwick

import 'package:flutter/material.dart';

import '../../messages/app_localizations.dart';
import '../shared/document_list_page.dart';
import '../shared/form_sheet.dart';

class AllergyPage extends StatelessWidget {
  const AllergyPage({super.key});

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;

    return DocumentListPage(
      feature: 'ALLERGY',
      title: localizations.allergyTitle,
      emptyText: localizations.allergyEmpty,
      deleteConfirmText: (localizations) => localizations.allergyDeleteConfirm,
      icon: Icons.warning_amber_outlined,
      summarize: (fields, localizations) => (
        fields['name'] as String? ?? '-',
        [
          if (fields['severity'] case final String severity)
            (
              localizations.allergySeverity,
              switch (severity) {
                'mild' => localizations.severityMild,
                'moderate' => localizations.severityModerate,
                'severe' => localizations.severitySevere,
                'life-threatening' => localizations.severityLifeThreatening,
                _ => severity,
              },
            ),
        ],
      ),
      formBuilder: (initialFields) => _AllergyFormSheet(initialFields: initialFields),
    );
  }
}

class _AllergyFormSheet extends StatefulWidget {
  final Map<String, dynamic>? initialFields;

  const _AllergyFormSheet({this.initialFields});

  @override
  State<_AllergyFormSheet> createState() => _AllergyFormSheetState();
}

class _AllergyFormSheetState extends State<_AllergyFormSheet> {
  late final TextEditingController _nameController;
  late final TextEditingController _notesController;
  String? _severity;
  bool _submitted = false;
  bool _showCustomInput = false;
  bool _initialized = false;

  static const _severityKeys = ['mild', 'moderate', 'severe', 'life-threatening'];

  @override
  void initState() {
    super.initState();
    final initial = widget.initialFields ?? {};
    _nameController = TextEditingController(
      text: initial['name'] as String? ?? '',
    );
    _notesController = TextEditingController(
      text: initial['notes'] as String? ?? '',
    );
    _severity = initial['severity'] as String?;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (_initialized) {
      return;
    }

    _initialized = true;

    final existingName = (widget.initialFields ?? {})['name'] as String? ?? '';

    if (existingName.isEmpty) {
      return;
    }

    final localizations = AppLocalizations.of(context)!;

    _showCustomInput = !_allergyList(localizations).contains(existingName);
  }

  List<String> _allergyList(AppLocalizations localizations) => [
    localizations.allergyPredefinedPeanuts,
    localizations.allergyPredefinedTreeNuts,
    localizations.allergyPredefinedMilk,
    localizations.allergyPredefinedEggs,
    localizations.allergyPredefinedWheat,
    localizations.allergyPredefinedSoy,
    localizations.allergyPredefinedFish,
    localizations.allergyPredefinedShellfish,
    localizations.allergyPredefinedSesame,
    localizations.allergyPredefinedPenicillin,
    localizations.allergyPredefinedAspirin,
    localizations.allergyPredefinedIbuprofen,
    localizations.allergyPredefinedNsaids,
    localizations.allergyPredefinedLatex,
    localizations.allergyPredefinedPollen,
    localizations.allergyPredefinedDustMites,
    localizations.allergyPredefinedCatHair,
    localizations.allergyPredefinedDogHair,
    localizations.allergyPredefinedBeeWasp,
    localizations.allergyPredefinedNickel,
    localizations.allergyPredefinedFragrance,
    localizations.allergyPredefinedMold,
    localizations.allergyPredefinedSulphites,
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _selectPredefined(String name) {
    setState(() {
      _nameController.text = name;
      _showCustomInput = false;
    });
  }

  void _submit() {
    setState(() => _submitted = true);

    final name = _nameController.text.trim();

    if (name.isEmpty) {
      return;
    }

    final fields = {
      'name': name,
      if (_severity != null) 'severity': _severity,
      if (_notesController.text.trim().isNotEmpty)
        'notes': _notesController.text.trim(),
    };

    Navigator.of(context).pop(fields);
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final isEditing = widget.initialFields != null;
    final nameError = _submitted && _nameController.text.trim().isEmpty
        ? localizations.allergyNameRequired
        : null;
    final allergyList = _allergyList(localizations);

    return FormSheet(
      title: isEditing ? localizations.allergyEditTitle : localizations.allergyManualTitle,
      children: [
        Text(
          localizations.allergySelectFromList,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ...allergyList.map(
              (name) => ChoiceChip(
                label: Text(name),
                selected: _nameController.text == name,
                onSelected: (_) => _selectPredefined(name),
              ),
            ),
            ChoiceChip(
              label: Text(localizations.allergyCustom),
              selected: _showCustomInput,
              onSelected: (_) {
                setState(() {
                  _showCustomInput = true;
                  _nameController.clear();
                });
              },
            ),
          ],
        ),
        if (_showCustomInput || nameError != null) ...[
          const SizedBox(height: 12),
          TextField(
            controller: _nameController,
            decoration: InputDecoration(
              labelText: '${localizations.allergyNameHint} *',
              errorText: nameError,
            ),
            textCapitalization: TextCapitalization.sentences,
            autofocus: _showCustomInput,
          ),
        ] else if (_submitted && _nameController.text.trim().isEmpty) ...[
          const SizedBox(height: 8),
          Text(
            localizations.allergyNameRequired,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.error,
            ),
          ),
        ],
        const SizedBox(height: 16),
        InputDecorator(
          decoration: InputDecoration(
            labelText: localizations.allergySeverity,
            suffixIcon: _severity != null
                ? IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: () => setState(() => _severity = null),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  )
                : null,
          ),
          isEmpty: _severity == null,
          child: DropdownButton<String>(
            value: _severity,
            isExpanded: true,
            underline: const SizedBox(),
            items: _severityKeys.asMap().entries.map((entry) {
              final label = [
                localizations.severityMild,
                localizations.severityModerate,
                localizations.severitySevere,
                localizations.severityLifeThreatening,
              ][entry.key];

              return DropdownMenuItem(value: entry.value, child: Text(label));
            }).toList(),
            onChanged: (value) => setState(() => _severity = value),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _notesController,
          decoration: InputDecoration(
            labelText: localizations.documentNotesHint,
          ),
          maxLines: 2,
        ),
        const SizedBox(height: 20),
        ElevatedButton(
          onPressed: _submit,
          child: Text(localizations.documentSave),
        ),
      ],
    );
  }
}
