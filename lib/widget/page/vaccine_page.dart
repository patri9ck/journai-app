// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Patrick Zwick

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart' show ImagePicker, ImageSource, XFile;

import '../../messages/app_localizations.dart';
import '../../model/data.dart';
import '../../model/limits.dart';
import '../../model/result.dart';
import '../../service/services.dart';
import '../shared/document_shared.dart';
import '../shared/empty_state.dart';
import '../shared/scanning_dialog.dart';
import '../sheet/encryption_sheet.dart';
import '../sheet/health_data_consent_sheet.dart';
import '../sheet/paywall_sheet.dart';
import '../shared/loading_button.dart';

const _feature = 'VACCINE';

class VaccinePage extends StatefulWidget {
  const VaccinePage({super.key});

  @override
  State<VaccinePage> createState() => _VaccinePageState();
}

class _VaccinePageState extends State<VaccinePage> {
  List<Data> _vaccines = [];
  Limits _limits = Limits.unlimited;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadVaccines());
  }

  Future<void> _loadVaccines() async {
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

    final cachedVaccines = await dataService.getCachedData([_feature]);

    if (!mounted) {
      return;
    }

    if (cachedVaccines.isNotEmpty) {
      setState(() {
        _vaccines = cachedVaccines;
        _loading = false;
      });
    }

    final freshLimitsFuture = limitsService.getLimits();
    final freshResultFuture = dataService.getData([_feature]);

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
        _vaccines = freshResult.value ?? [];
        _loading = false;
      });
    } else if (_vaccines.isEmpty) {
      setState(() => _loading = false);
      (freshResult as Failure).show(AppLocalizations.of(context));
    } else {
      setState(() => _loading = false);
    }
  }

  int get _vaccineRemaining {
    final limit = _limits.features[_feature];
    if (limit == null || limit == -1) {
      return -1;
    }
    return (limit - _vaccines.length).clamp(0, limit);
  }

  bool get _isOverLimit {
    final limit = _limits.features[_feature];
    if (limit == null || limit == -1) {
      return false;
    }
    return _vaccines.length > limit;
  }

  Future<void> _addManually() async {
    final localizations = AppLocalizations.of(context)!;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _VaccineFormSheet(
        onSave: (fields) async {
          final limit = _limits.features[_feature];
          final remaining = _vaccineRemaining;

          if (remaining != -1 && remaining == 0) {
            return localizations.failureSaveLimitFull(limit!, localizations.vaccinesTitle);
          }

          final encryptionReady = await ensureEncryptionUnlocked(context);

          if (!encryptionReady || !context.mounted) {
            return localizations.failure;
          }

          final result = await dataService.saveData(
            Data(feature: _feature, fields: fields),
          );

          if (result is Failure<void>) {
            return result.localizedMessage(localizations);
          }

          return null;
        },
      ),
    );

    if (mounted) {
      await _loadVaccines();
    }
  }

  Future<void> _pickAndScan() async {
    final localizations = AppLocalizations.of(context)!;

    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (_) => _ImageSourceSheet(),
    );

    if (source == null || !mounted) {
      return;
    }

    final picker = ImagePicker();
    final initialPhotos = <XFile>[];

    if (source == ImageSource.camera) {
      final photo = await picker.pickImage(source: ImageSource.camera, imageQuality: 85);

      if (photo == null || !mounted) {
        return;
      }

      initialPhotos.add(photo);
    } else {
      initialPhotos.addAll(await picker.pickMultiImage(imageQuality: 85));
    }

    if (initialPhotos.isEmpty || !mounted) {
      return;
    }

    final pickedFiles = await showModalBottomSheet<List<XFile>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _PhotoPreviewSheet(initialPhotos: initialPhotos),
    );

    if (pickedFiles == null || pickedFiles.isEmpty || !mounted) {
      return;
    }

    final hasConsent = await ensureHealthDataConsent(context);

    if (!hasConsent || !mounted) {
      return;
    }

    final imageBytesList = await Future.wait(
      pickedFiles.map((file) => file.readAsBytes()),
    );

    if (!mounted) {
      return;
    }

    showScanningDialog(context, localizations.documentScanning);

    final result = await dataService.scanImages(_feature, imageBytesList);

    if (!mounted) {
      return;
    }

    Navigator.of(context).pop();

    if (result is! Success<List<Map<String, dynamic>>>) {
      (result as Failure).show(localizations);
      return;
    }

    final analysedItems = result.value ?? [];

    if (analysedItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(localizations.vaccineScanEmpty, textAlign: TextAlign.center)),
      );
      return;
    }

    if (!mounted) {
      return;
    }

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _ScanResultSheet(
        scannedFields: analysedItems,
        onSaved: _loadVaccines,
        categoryDisplayName: AppLocalizations.of(context)!.vaccinesTitle,
        categoryLimit: _limits.features[_feature],
        existingCount: _vaccines.length,
      ),
    );
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
                    title: Text(localizations.vaccinesTitle),
                    floating: true,
                    snap: true,
                  ),
                  if (_vaccines.isEmpty)
                    SliverFillRemaining(
                      child: EmptyState(
                        icon: Icons.vaccines_outlined,
                        text: localizations.vaccinesEmpty,
                        actions: [
                          OutlinedButton.icon(
                            onPressed: _pickAndScan,
                            icon: const Icon(Icons.document_scanner_outlined, size: 18),
                            label: Text(localizations.documentScan),
                          ),
                          OutlinedButton.icon(
                            onPressed: _addManually,
                            icon: const Icon(Icons.edit_outlined, size: 18),
                            label: Text(localizations.documentAddManually),
                          ),
                        ],
                      ),
                    )
                  else
                    if (_isOverLimit)
                      SliverToBoxAdapter(
                        child: OverLimitBanner(
                          featureName: localizations.vaccinesTitle,
                          onUpgrade: () => showPaywall(context),
                        ),
                      ),
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) => _VaccineCard(
                            vaccine: _vaccines[index],
                            onChanged: _loadVaccines,
                          ),
                          childCount: _vaccines.length,
                        ),
                      ),
                    ),
                ],
              ),
      ),
      floatingActionButton: _loading || _vaccines.isEmpty
          ? null
          : Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                FloatingActionButton.small(
                  heroTag: 'manual',
                  onPressed: _addManually,
                  tooltip: localizations.documentAddManually,
                  child: const Icon(Icons.edit_outlined),
                ),
                const SizedBox(height: 8),
                FloatingActionButton.extended(
                  heroTag: 'analyse',
                  onPressed: _pickAndScan,
                  icon: const Icon(Icons.document_scanner_outlined),
                  label: Text(localizations.documentScan),
                ),
              ],
            ),
    );
  }
}

class _VaccineCard extends StatelessWidget {
  final Data vaccine;
  final VoidCallback onChanged;

  const _VaccineCard({required this.vaccine, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final fields = vaccine.fields;
    final name = fields['name'] as String? ?? '-';

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: theme.colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.vaccines_outlined, color: theme.colorScheme.primary, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: theme.textTheme.titleSmall),
                  if (fields['disease'] case final String disease) ...[
                    const SizedBox(height: 4),
                    InfoRow(label: localizations.vaccineDiseaseHint.split(' ').first, value: disease),
                  ],
                  if (fields['date'] case final String date) ...[
                    const SizedBox(height: 2),
                    InfoRow(label: localizations.vaccineDate, value: date),
                  ],
                  if (fields['nextDate'] case final String nextDate) ...[
                    const SizedBox(height: 2),
                    InfoRow(label: localizations.vaccineNextDate, value: nextDate),
                  ],
                  if (fields['manufacturer'] case final String manufacturer) ...[
                    const SizedBox(height: 2),
                    InfoRow(label: localizations.vaccineManufacturer, value: manufacturer),
                  ],
                  if (fields['batchNumber'] case final String batchNumber) ...[
                    const SizedBox(height: 2),
                    InfoRow(label: localizations.vaccineBatchNumber, value: batchNumber),
                  ],
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.edit_outlined, size: 18),
              onPressed: () => _edit(context, localizations),
              color: theme.colorScheme.onSurface.withValues(alpha: 0.35),
              padding: const EdgeInsets.all(8),
              constraints: const BoxConstraints(),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 18),
              onPressed: () => _confirmDelete(context, localizations),
              color: theme.colorScheme.onSurface.withValues(alpha: 0.35),
              padding: const EdgeInsets.all(8),
              constraints: const BoxConstraints(),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _edit(BuildContext context, AppLocalizations localizations) async {
    final updated = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _VaccineFormSheet(initialFields: vaccine.fields),
    );

    if (updated == null || !context.mounted) {
      return;
    }

    final encryptionReady = await ensureEncryptionUnlocked(context);

    if (!encryptionReady || !context.mounted) {
      return;
    }

    final result = await dataService.updateData(
      vaccine.id!,
      Data(feature: _feature, fields: updated),
    );

    if (!context.mounted) {
      return;
    }

    if (result is Failure<void>) {
      result.show(AppLocalizations.of(context));
      return;
    }

    onChanged();
  }

  Future<void> _confirmDelete(BuildContext context, AppLocalizations localizations) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        content: Text(localizations.vaccineDeleteConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(localizations.back),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(
              localizations.vaccineDeleteConfirmYes,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) {
      return;
    }

    final result = await dataService.deleteData(vaccine.id!);

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

class _ImageSourceSheet extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.camera_alt_outlined),
            title: Text(localizations.vaccinePickCamera),
            onTap: () => Navigator.of(context).pop(ImageSource.camera),
          ),
          ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: Text(localizations.vaccinePickGallery),
            onTap: () => Navigator.of(context).pop(ImageSource.gallery),
          ),
        ],
      ),
    );
  }
}

class _ScanResultSheet extends StatefulWidget {
  final List<Map<String, dynamic>> scannedFields;
  final VoidCallback onSaved;

  final int? categoryLimit;
  final int existingCount;
  final String categoryDisplayName;

  const _ScanResultSheet({
    required this.scannedFields,
    required this.onSaved,
    required this.categoryDisplayName,
    this.categoryLimit,
    this.existingCount = 0,
  });

  @override
  State<_ScanResultSheet> createState() => _ScanResultSheetState();
}

class _ScanResultSheetState extends State<_ScanResultSheet> {
  late List<Map<String, dynamic>> _items;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _items = List.of(widget.scannedFields);
  }

  void _deleteItem(int index) {
    setState(() => _items.removeAt(index));

    if (_items.isEmpty) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _editItem(int index) async {
    final updated = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _VaccineFormSheet(initialFields: _items[index]),
    );

    if (updated == null || !mounted) {
      return;
    }

    setState(() => _items[index] = updated);
  }

  Future<void> _addItem() async {
    final fields = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => const _VaccineFormSheet(),
    );

    if (fields == null || !mounted) {
      return;
    }

    setState(() => _items.add(fields));
  }

  int get _remaining {
    final limit = widget.categoryLimit;
    if (limit == null || limit == -1) {
      return -1;
    }
    return (limit - widget.existingCount).clamp(0, limit);
  }

  Future<void> _saveAll() async {
    if (!mounted) {
      return;
    }

    setState(() => _error = null);

    final localizations = AppLocalizations.of(context)!;
    final remaining = _remaining;

    if (remaining != -1 && _items.length > remaining) {
      setState(() {
        _error = remaining == 0
            ? localizations.failureSaveLimitFull(
                widget.categoryLimit!,
                widget.categoryDisplayName,
              )
            : localizations.failureSaveLimitExcess(
                remaining,
                widget.categoryDisplayName,
                _items.length,
                _items.length - remaining,
              );
      });
      return;
    }

    final encryptionReady = await ensureEncryptionUnlocked(context);

    if (!encryptionReady || !mounted) {
      return;
    }

    setState(() => _saving = true);

    final navigator = Navigator.of(context);

    int savedCount = 0;

    for (final fields in List.of(_items)) {
      final result = await dataService.saveData(
        Data(feature: _feature, fields: fields),
      );

      if (!mounted) {
        return;
      }

      if (result is Failure<void>) {
        setState(() {
          _items.removeRange(0, savedCount);
          _saving = false;
          _error = result.localizedMessage(AppLocalizations.of(context));
        });
        return;
      }

      savedCount++;
    }

    if (!mounted) {
      return;
    }

    navigator.pop();
    widget.onSaved();
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 24,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(localizations.documentScanResult, style: theme.textTheme.headlineSmall),
            const SizedBox(height: 4),
            Text(localizations.documentScanResultSubtitle, style: theme.textTheme.bodySmall),
            const SizedBox(height: 16),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ..._items.asMap().entries.map(
                      (entry) => _ScanResultCard(
                        fields: entry.value,
                        onEdit: () => _editItem(entry.key),
                        onDelete: () => _deleteItem(entry.key),
                        localizations: localizations,
                        theme: theme,
                      ),
                    ),
                    TextButton.icon(
                      onPressed: _addItem,
                      icon: const Icon(Icons.add, size: 18),
                      label: Text(localizations.vaccineAddAnother),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            if (_error != null) ...[
              Text(
                _error!,
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
            ],
            LoadingButton(loading: _saving, onPressed: _saveAll, label: localizations.vaccineSave),
          ],
        ),
      ),
    );
  }
}

class _ScanResultCard extends StatelessWidget {
  final Map<String, dynamic> fields;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final AppLocalizations localizations;
  final ThemeData theme;

  const _ScanResultCard({
    required this.fields,
    required this.onEdit,
    required this.onDelete,
    required this.localizations,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.onSurface.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(fields['name'] as String? ?? '-', style: theme.textTheme.titleSmall),
                if (fields['disease'] case final String disease) ...[
                  const SizedBox(height: 4),
                  InfoRow(label: localizations.vaccineDiseaseHint.split(' ').first, value: disease),
                ],
                if (fields['date'] case final String date) ...[
                  const SizedBox(height: 2),
                  InfoRow(label: localizations.vaccineDate, value: date),
                ],
                if (fields['nextDate'] case final String nextDate) ...[
                  const SizedBox(height: 2),
                  InfoRow(label: localizations.vaccineNextDate, value: nextDate),
                  const SizedBox(height: 4),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 12,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          localizations.vaccineScanNextDateNote,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                if (fields['manufacturer'] case final String manufacturer) ...[
                  const SizedBox(height: 2),
                  InfoRow(label: localizations.vaccineManufacturer, value: manufacturer),
                ],
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.edit_outlined, size: 18),
            onPressed: onEdit,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.35),
            padding: const EdgeInsets.all(8),
            constraints: const BoxConstraints(),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 18),
            onPressed: onDelete,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.35),
            padding: const EdgeInsets.all(8),
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }
}

class _VaccineFormSheet extends StatefulWidget {
  final Map<String, dynamic>? initialFields;
  final Future<String?> Function(Map<String, dynamic> fields)? onSave;

  const _VaccineFormSheet({this.initialFields, this.onSave});

  @override
  State<_VaccineFormSheet> createState() => _VaccineFormSheetState();
}

class _VaccineFormSheetState extends State<_VaccineFormSheet> {
  late final TextEditingController _nameController;
  late final TextEditingController _diseaseController;
  late final TextEditingController _dateController;
  late final TextEditingController _nextDateController;
  late final TextEditingController _manufacturerController;
  late final TextEditingController _batchNumberController;
  bool _submitted = false;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialFields ?? {};
    _nameController = TextEditingController(text: initial['name'] as String? ?? '');
    _diseaseController = TextEditingController(text: initial['disease'] as String? ?? '');
    _dateController = TextEditingController(text: initial['date'] as String? ?? '');
    _nextDateController = TextEditingController(text: initial['nextDate'] as String? ?? '');
    _manufacturerController = TextEditingController(text: initial['manufacturer'] as String? ?? '');
    _batchNumberController = TextEditingController(text: initial['batchNumber'] as String? ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _diseaseController.dispose();
    _dateController.dispose();
    _nextDateController.dispose();
    _manufacturerController.dispose();
    _batchNumberController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _submitted = true;
      _error = null;
    });

    final name = _nameController.text.trim();

    if (name.isEmpty) {
      return;
    }

    final fields = {
      'name': name,
      if (_diseaseController.text.trim().isNotEmpty) 'disease': _diseaseController.text.trim(),
      if (_dateController.text.trim().isNotEmpty) 'date': _dateController.text.trim(),
      if (_nextDateController.text.trim().isNotEmpty) 'nextDate': _nextDateController.text.trim(),
      if (_manufacturerController.text.trim().isNotEmpty) 'manufacturer': _manufacturerController.text.trim(),
      if (_batchNumberController.text.trim().isNotEmpty) 'batchNumber': _batchNumberController.text.trim(),
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
    final nameError = _submitted && _nameController.text.trim().isEmpty
        ? localizations.vaccineNameRequired
        : null;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 24,
          bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                isEditing ? localizations.vaccineEditTitle : localizations.vaccineManualTitle,
                style: theme.textTheme.headlineSmall,
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: '${localizations.vaccineNameHint} *',
                  errorText: nameError,
                ),
                textCapitalization: TextCapitalization.sentences,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _diseaseController,
                decoration: InputDecoration(labelText: localizations.vaccineDiseaseHint),
                textCapitalization: TextCapitalization.sentences,
              ),
              const SizedBox(height: 12),
              DatePickerField(
                controller: _dateController,
                labelText: localizations.vaccineDateHint,
              ),
              const SizedBox(height: 12),
              DatePickerField(
                controller: _nextDateController,
                labelText: localizations.vaccineNextDateHint,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _manufacturerController,
                decoration: InputDecoration(labelText: localizations.vaccineManufacturerHint),
                textCapitalization: TextCapitalization.sentences,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _batchNumberController,
                decoration: InputDecoration(labelText: localizations.vaccineBatchNumberHint),
              ),
              const SizedBox(height: 20),
              if (_error != null) ...[
                Text(
                  _error!,
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
              ],
              LoadingButton(loading: _saving, onPressed: _submit, label: localizations.vaccineSave),
            ],
          ),
        ),
      ),
    );
  }
}

class _PhotoPreviewSheet extends StatefulWidget {
  final List<XFile> initialPhotos;

  const _PhotoPreviewSheet({required this.initialPhotos});

  @override
  State<_PhotoPreviewSheet> createState() => _PhotoPreviewSheetState();
}

class _PhotoPreviewSheetState extends State<_PhotoPreviewSheet> {
  late List<XFile> _photos;

  @override
  void initState() {
    super.initState();
    _photos = List.of(widget.initialPhotos);
  }

  Future<void> _addPhoto() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (_) => _ImageSourceSheet(),
    );

    if (source == null || !mounted) {
      return;
    }

    final picker = ImagePicker();

    if (source == ImageSource.camera) {
      final photo = await picker.pickImage(source: ImageSource.camera, imageQuality: 85);

      if (photo == null || !mounted) {
        return;
      }

      setState(() => _photos.add(photo));
    } else {
      final photos = await picker.pickMultiImage(imageQuality: 85);

      if (!mounted) {
        return;
      }

      setState(() => _photos.addAll(photos));
    }
  }

  void _viewPhoto(XFile photo) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _FullScreenPhotoPage(photo: photo),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 24,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(localizations.vaccinePhotosTitle, style: theme.textTheme.headlineSmall),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ..._photos.asMap().entries.map(
                  (entry) => _PhotoThumbnail(
                    photo: entry.value,
                    onRemove: () => setState(() => _photos.removeAt(entry.key)),
                    onTap: () => _viewPhoto(entry.value),
                  ),
                ),
                _AddPhotoTile(onTap: _addPhoto),
              ],
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _photos.isEmpty ? null : () => Navigator.of(context).pop(_photos),
              child: Text(localizations.documentScan),
            ),
          ],
        ),
      ),
    );
  }
}

class _PhotoThumbnail extends StatelessWidget {
  final XFile photo;
  final VoidCallback onRemove;
  final VoidCallback onTap;

  const _PhotoThumbnail({required this.photo, required this.onRemove, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 96,
      height: 96,
      child: Stack(
        children: [
          GestureDetector(
            onTap: onTap,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.file(
                File(photo.path),
                width: 96,
                height: 96,
                fit: BoxFit.cover,
              ),
            ),
          ),
          Positioned(
            top: 4,
            right: 4,
            child: GestureDetector(
              onTap: onRemove,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.close, size: 14, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AddPhotoTile extends StatelessWidget {
  final VoidCallback onTap;

  const _AddPhotoTile({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 96,
        height: 96,
        decoration: BoxDecoration(
          border: Border.all(color: theme.colorScheme.outline),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          Icons.add_photo_alternate_outlined,
          color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
        ),
      ),
    );
  }
}

class _FullScreenPhotoPage extends StatelessWidget {
  final XFile photo;

  const _FullScreenPhotoPage({required this.photo});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Center(
        child: InteractiveViewer(
          child: Image.file(File(photo.path)),
        ),
      ),
    );
  }
}
