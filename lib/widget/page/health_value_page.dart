// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Patrick Zwick

import 'package:flutter/material.dart';

import '../../messages/app_localizations.dart';
import '../../model/data.dart';
import '../../model/limits.dart';
import '../../model/result.dart';
import '../../service/services.dart';
import '../../util/storage.dart';
import '../shared/document_shared.dart';
import '../shared/empty_state.dart';
import '../sheet/encryption_sheet.dart';
import '../shared/form_sheet.dart';

String _categoryForKey(String key, AppLocalizations localizations) {
  final map = {
    localizations.healthKeyBloodType: 'BLOOD_TYPE',
    localizations.healthKeyAge: 'AGE',
    localizations.healthKeyHeight: 'HEIGHT',
    localizations.healthKeyWeight: 'WEIGHT',
    localizations.healthKeyBmi: 'BMI',
    localizations.healthKeyEyeColor: 'EYE_COLOR',
    localizations.healthKeyHairColor: 'HAIR_COLOR',
    localizations.healthKeyOrganDonor: 'ORGAN_DONOR',
    localizations.healthKeyRhFactor: 'RH_FACTOR',
  };

  return map[key] ?? 'MISCELLANEOUS';
}

class HealthValuePage extends StatefulWidget {
  const HealthValuePage({super.key});

  @override
  State<HealthValuePage> createState() => _HealthValuePageState();
}

class _HealthValuePageState extends State<HealthValuePage> {
  List<Data> _documents = [];
  Limits _limits = Limits.unlimited;
  bool _loading = true;
  bool _metricUnits = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final unitValue = await storage.read(key: 'settings_units_metric');

    if (mounted) {
      setState(() => _metricUnits = unitValue != 'false');
    }

    final cachedLimits = await limitsService.getCachedLimits();

    if (!mounted) {
      return;
    }

    setState(() => _limits = cachedLimits);

    final encryptionReady = await ensureEncryptionUnlocked(context);

    if (!encryptionReady || !mounted) {
      setState(() => _loading = false);

      return;
    }

    final cachedDocuments = await dataService.getCachedData(Limits.healthValueFeatures);

    if (!mounted) {
      return;
    }

    if (cachedDocuments.isNotEmpty) {
      setState(() {
        _documents = cachedDocuments;
        _loading = false;
      });
    }

    final freshLimitsFuture = limitsService.getLimits();
    final freshResultFuture = dataService.getData(Limits.healthValueFeatures);

    final freshLimits = await freshLimitsFuture;

    if (!mounted) {
      return;
    }

    setState(() => _limits = freshLimits);

    final freshResult = await freshResultFuture;

    if (!mounted) {
      return;
    }

    if (freshResult is Success<List<Data>>) {
      setState(() {
        _documents = freshResult.value ?? [];
        _loading = false;
      });
    } else if (_documents.isEmpty) {
      setState(() => _loading = false);
      (freshResult as Failure).show(AppLocalizations.of(context));
    } else {
      setState(() => _loading = false);
    }
  }

  Future<void> _add() async {
    final localizations = AppLocalizations.of(context)!;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _HealthValueFormSheet(
        limits: _limits,
        onSave: (fields) => _saveHealthValue(
          Data(
            feature: _categoryForKey(fields['key'] as String? ?? '', localizations),
            fields: fields,
          ),
          localizations,
        ),
      ),
    );

    if (mounted) {
      _load();
    }
  }

  Future<String?> _saveHealthValue(Data data, AppLocalizations localizations) async {
    final encryptionReady = await ensureEncryptionUnlocked(context);

    if (!encryptionReady || !context.mounted) {
      return localizations.failure;
    }

    final result = await dataService.saveData(data);

    if (result is Failure<void>) {
      if (result is ServerFailure<void> && result.key == 'limit-exceeded') {
        return localizations.featureNotAvailableInPlan;
      }

      if (result is NetworkFailure<void>) {
        return localizations.failureNoInternet;
      }

      return localizations.failure;
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;

    return Scaffold(
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : CustomScrollView(
                slivers: [
                  SliverAppBar(
                    title: Text(localizations.healthValueTitle),
                    floating: true,
                    snap: true,
                  ),
                  if (_documents.isEmpty)
                    SliverFillRemaining(
                      child: EmptyState(
                        icon: Icons.monitor_heart_outlined,
                        text: localizations.healthValueEmpty,
                        actions: [
                          OutlinedButton.icon(
                            onPressed: _add,
                            icon: const Icon(Icons.add, size: 18),
                            label: Text(localizations.documentAddManually),
                          ),
                        ],
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) => _HealthValueItem(
                            data: _documents[index],
                            limits: _limits,
                            metricUnits: _metricUnits,
                            onChanged: _load,
                          ),
                          childCount: _documents.length,
                        ),
                      ),
                    ),
                ],
              ),
      ),
      floatingActionButton: _loading || _documents.isEmpty
          ? null
          : FloatingActionButton(
              onPressed: _add,
              child: const Icon(Icons.add),
            ),
    );
  }
}

class _HealthValueItem extends StatelessWidget {
  final Data data;
  final Limits limits;
  final bool metricUnits;
  final VoidCallback onChanged;

  const _HealthValueItem({
    required this.data,
    required this.limits,
    required this.metricUnits,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final fields = data.fields;
    final key = fields['key'] as String? ?? '-';
    final rawValue = fields['value'] as String? ?? '-';

    String displayValue = rawValue;

    if (!metricUnits) {
      final category = _categoryForKey(key, localizations);
      final numericValue = double.tryParse(rawValue);

      if (numericValue != null) {
        final converted = switch (category) {
          'HEIGHT' => '${(numericValue / 2.54).toStringAsFixed(1)} in',
          'WEIGHT' => '${(numericValue * 2.20462).toStringAsFixed(1)} lbs',
          _ => null,
        };

        if (converted != null) {
          displayValue = converted;
        }
      }
    }

    return DocumentCard(
      icon: Icons.monitor_heart_outlined,
      title: key,
      details: [(localizations.healthValueValue, displayValue)],
      onEdit: () => _edit(context, localizations),
      onDelete: () => _delete(context, localizations),
    );
  }

  Future<void> _edit(BuildContext context, AppLocalizations localizations) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _HealthValueFormSheet(
        initialFields: data.fields,
        limits: limits,
        onSave: (fields) async {
          if (!context.mounted) {
            return localizations.failure;
          }

          final encryptionReady = await ensureEncryptionUnlocked(context);

          if (!encryptionReady || !context.mounted) {
            return localizations.failure;
          }

          final result = await dataService.updateData(
            data.id!,
            Data(feature: data.feature, fields: fields),
          );

          if (result is Failure<void>) {
            if (result is NetworkFailure<void>) {
              return localizations.failureNoInternet;
            }
            return localizations.failure;
          }

          return null;
        },
      ),
    );

    if (context.mounted) {
      onChanged();
    }
  }

  Future<void> _delete(BuildContext context, AppLocalizations localizations) async {
    final confirmed = await confirmDelete(
      context,
      localizations.healthValueDeleteConfirm,
      localizations.documentDeleteConfirmYes,
    );

    if (!confirmed || !context.mounted) {
      return;
    }

    final result = await dataService.deleteData(data.id!);

    if (!context.mounted) {
      return;
    }

    if (result is Failure<void>) {
      result.show(AppLocalizations.of(context));
      return;
    }

    onChanged();
  }
}

class _HealthValueFormSheet extends StatefulWidget {
  final Map<String, dynamic>? initialFields;
  final Limits limits;

  final Future<String?> Function(Map<String, dynamic> fields)? onSave;

  const _HealthValueFormSheet({
    this.initialFields,
    this.limits = Limits.unlimited,
    this.onSave,
  });

  @override
  State<_HealthValueFormSheet> createState() => _HealthValueFormSheetState();
}

class _HealthValueFormSheetState extends State<_HealthValueFormSheet> {
  late final TextEditingController _keyController;
  late final TextEditingController _valueController;
  late final TextEditingController _notesController;
  bool _submitted = false;
  bool _saving = false;
  String? _error;
  bool _showCustomKey = false;
  bool _showCustomValue = false;
  bool _initialized = false;
  bool _metricUnits = true;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialFields ?? {};
    _keyController = TextEditingController(
      text: initial['key'] as String? ?? '',
    );
    _valueController = TextEditingController(
      text: initial['value'] as String? ?? '',
    );
    _notesController = TextEditingController(
      text: initial['notes'] as String? ?? '',
    );
    _loadUnits();
  }

  Future<void> _loadUnits() async {
    final value = await storage.read(key: 'settings_units_metric');
    final metricUnits = value != 'false';

    if (!mounted) {
      return;
    }

    if (!metricUnits) {
      final localizations = AppLocalizations.of(context)!;
      final category = _categoryForKey(_keyController.text, localizations);
      final initialValue = (widget.initialFields ?? {})['value'] as String? ?? '';
      final numericValue = double.tryParse(initialValue);

      if (numericValue != null) {
        final displayValue = switch (category) {
          'HEIGHT' => (numericValue / 2.54).toStringAsFixed(1),
          'WEIGHT' => (numericValue * 2.20462).toStringAsFixed(1),
          _ => null,
        };

        if (displayValue != null) {
          _valueController.text = displayValue;
        }
      }
    }

    setState(() => _metricUnits = metricUnits);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (_initialized) {
      return;
    }

    _initialized = true;

    final initial = widget.initialFields ?? {};
    final existingKey = initial['key'] as String? ?? '';
    final existingValue = initial['value'] as String? ?? '';

    if (existingKey.isEmpty) {
      return;
    }

    final localizations = AppLocalizations.of(context)!;
    _showCustomKey = _categoryForKey(existingKey, localizations) == 'HEALTH_VALUE';

    final existingCategory = _categoryForKey(existingKey, localizations);

    if (existingCategory == 'EYE_COLOR' || existingCategory == 'HAIR_COLOR') {
      if (existingValue.isNotEmpty) {
        final eyeColors = _eyeColorList(localizations);
        final hairColors = _hairColorList(localizations);
        _showCustomValue = !eyeColors.contains(existingValue) && !hairColors.contains(existingValue);
      }
    }
  }

  List<String> _eyeColorList(AppLocalizations localizations) => [
    localizations.eyeColorBrown,
    localizations.eyeColorBlue,
    localizations.eyeColorGreen,
    localizations.eyeColorHazel,
    localizations.eyeColorGray,
    localizations.eyeColorTeal,
  ];

  List<String> _hairColorList(AppLocalizations localizations) => [
    localizations.hairColorBlack,
    localizations.hairColorDarkBrown,
    localizations.hairColorBrown,
    localizations.hairColorLightBrown,
    localizations.hairColorBlonde,
    localizations.hairColorRed,
    localizations.hairColorGray,
    localizations.hairColorWhite,
  ];

  @override
  void dispose() {
    _keyController.dispose();
    _valueController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _selectPredefinedKey(String key) {
    setState(() {
      _keyController.text = key;
      _valueController.clear();
      _showCustomKey = false;
      _showCustomValue = false;
    });
  }

  Widget _buildDropdown({
    required AppLocalizations localizations,
    required String? valueError,
    required List<String> options,
  }) {
    final currentValue = _valueController.text;
    final selectedValue = options.contains(currentValue) ? currentValue : null;

    return InputDecorator(
      decoration: InputDecoration(
        labelText: '${localizations.healthValueValueHint} *',
        errorText: valueError,
      ),
      isEmpty: selectedValue == null,
      child: DropdownButton<String>(
        value: selectedValue,
        isExpanded: true,
        underline: const SizedBox(),
        items: options
            .map((option) => DropdownMenuItem(value: option, child: Text(option)))
            .toList(),
        onChanged: (value) => setState(() => _valueController.text = value ?? ''),
      ),
    );
  }

  Widget _buildDropdownWithCustom({
    required AppLocalizations localizations,
    required String? valueError,
    required List<String> options,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ...options.map(
              (option) => ChoiceChip(
                label: Text(option),
                selected: !_showCustomValue && _valueController.text == option,
                onSelected: (_) => setState(() {
                  _valueController.text = option;
                  _showCustomValue = false;
                }),
              ),
            ),
            ChoiceChip(
              label: Text(localizations.healthValueOther),
              selected: _showCustomValue,
              onSelected: (_) => setState(() {
                _showCustomValue = true;
                _valueController.clear();
              }),
            ),
          ],
        ),
        if (_showCustomValue) ...[
          const SizedBox(height: 12),
          TextField(
            controller: _valueController,
            decoration: InputDecoration(
              labelText: '${localizations.healthValueValueHint} *',
              errorText: valueError,
            ),
            textCapitalization: TextCapitalization.sentences,
            autofocus: true,
          ),
        ] else if (valueError != null) ...[
          const SizedBox(height: 4),
          Text(
            valueError,
            style: TextStyle(
              color: Theme.of(context).colorScheme.error,
              fontSize: 12,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildValueInput(AppLocalizations localizations, String? valueError) {
    final category = _categoryForKey(_keyController.text, localizations);

    if (category == 'BLOOD_TYPE') {
      return _buildDropdown(
        localizations: localizations,
        valueError: valueError,
        options: const ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', '0+', '0-'],
      );
    }

    if (category == 'RH_FACTOR') {
      return _buildDropdown(
        localizations: localizations,
        valueError: valueError,
        options: const ['+', '-'],
      );
    }

    if (category == 'ORGAN_DONOR') {
      return _buildDropdown(
        localizations: localizations,
        valueError: valueError,
        options: [localizations.healthValueYes, localizations.healthValueNo],
      );
    }

    if (category == 'EYE_COLOR') {
      return _buildDropdownWithCustom(
        localizations: localizations,
        valueError: valueError,
        options: _eyeColorList(localizations),
      );
    }

    if (category == 'HAIR_COLOR') {
      return _buildDropdownWithCustom(
        localizations: localizations,
        valueError: valueError,
        options: _hairColorList(localizations),
      );
    }

    final suffix = switch (category) {
      'HEIGHT' => _metricUnits ? 'cm' : 'in',
      'WEIGHT' => _metricUnits ? 'kg' : 'lbs',
      _ => null,
    };
    final isNumeric = category == 'HEIGHT' || category == 'WEIGHT' || category == 'AGE' || category == 'BMI';

    return TextField(
      controller: _valueController,
      decoration: InputDecoration(
        labelText: '${localizations.healthValueValueHint} *',
        errorText: valueError,
        suffix: suffix != null ? Text(suffix) : null,
      ),
      keyboardType: isNumeric
          ? const TextInputType.numberWithOptions(decimal: true)
          : TextInputType.text,
    );
  }

  Future<void> _submit() async {
    setState(() {
      _submitted = true;
      _error = null;
    });

    final key = _keyController.text.trim();
    final value = _valueController.text.trim();

    if (key.isEmpty || value.isEmpty) {
      return;
    }

    final localizations = AppLocalizations.of(context)!;
    final category = _categoryForKey(key, localizations);

    String storedValue = value;

    if (!_metricUnits) {
      final numericValue = double.tryParse(value);

      if (numericValue != null) {
        storedValue = switch (category) {
          'HEIGHT' => (numericValue * 2.54).toStringAsFixed(1),
          'WEIGHT' => (numericValue / 2.20462).toStringAsFixed(1),
          _ => value,
        };
      }
    }

    final fields = {
      'key': key,
      'value': storedValue,
      if (_notesController.text.trim().isNotEmpty)
        'notes': _notesController.text.trim(),
    };

    if (widget.onSave == null) {
      Navigator.of(context).pop(fields);
      return;
    }

    setState(() => _saving = true);

    final error = await widget.onSave!(fields);

    if (!mounted) {
      return;
    }

    if (error != null) {
      setState(() {
        _saving = false;
        _error = error;
      });
      return;
    }

    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final isEditing = widget.initialFields != null;
    final keyError = _submitted && _keyController.text.trim().isEmpty
        ? localizations.healthValueKeyRequired
        : null;
    final valueError = _submitted && _valueController.text.trim().isEmpty
        ? localizations.healthValueValueRequired
        : null;
    final keyList = [
      localizations.healthKeyBloodType,
      localizations.healthKeyAge,
      localizations.healthKeyHeight,
      localizations.healthKeyWeight,
      localizations.healthKeyBmi,
      localizations.healthKeyEyeColor,
      localizations.healthKeyHairColor,
      localizations.healthKeyOrganDonor,
      localizations.healthKeyRhFactor,
    ];

    return FormSheet(
      title: isEditing ? localizations.healthValueEditTitle : localizations.healthValueManualTitle,
      onSave: _submit,
      saving: _saving,
      children: [
        Text(
          localizations.healthValueSelectKey,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ...keyList.map((key) {
              final enabled = widget.limits.isFeatureEnabled(_categoryForKey(key, localizations));
              return Opacity(
                opacity: enabled ? 1.0 : 0.38,
                child: ChoiceChip(
                  label: Text(key),
                  selected: _keyController.text == key,
                  onSelected: enabled ? (_) => _selectPredefinedKey(key) : null,
                ),
              );
            }),
            Opacity(
              opacity: widget.limits.isFeatureEnabled('MISCELLANEOUS') ? 1.0 : 0.38,
              child: ChoiceChip(
                label: Text(localizations.customName),
                selected: _showCustomKey,
                onSelected: widget.limits.isFeatureEnabled('MISCELLANEOUS')
                    ? (_) {
                        setState(() {
                          _showCustomKey = true;
                          _keyController.clear();
                          _valueController.clear();
                        });
                      }
                    : null,
              ),
            ),
          ],
        ),
        if (_showCustomKey || keyError != null) ...[
          const SizedBox(height: 12),
          TextField(
            controller: _keyController,
            decoration: InputDecoration(
              labelText: '${localizations.healthValueKeyHint} *',
              errorText: keyError,
            ),
            textCapitalization: TextCapitalization.sentences,
            autofocus: _showCustomKey,
          ),
        ],
        const SizedBox(height: 12),
        _buildValueInput(localizations, valueError),
        const SizedBox(height: 12),
        TextField(
          controller: _notesController,
          decoration: InputDecoration(labelText: localizations.documentNotesHint),
          maxLines: 2,
        ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(
            _error!,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.error,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }
}
