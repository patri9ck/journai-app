// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Patrick Zwick

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../messages/app_localizations.dart';
import '../../model/data.dart';
import '../../model/result.dart';
import '../../service/services.dart';
import '../sheet/encryption_sheet.dart';
import 'document_shared.dart';
import 'empty_state.dart';
import 'scanning_dialog.dart';
import 'loading_button.dart';

typedef DocumentSummary = (String title, List<(String, String)> details);

Future<List<Uint8List?>?> pickScanImages(BuildContext context) async {
  final photos = await pickDocumentImages(context, multipleAllowed: true);

  if (photos == null || photos.isEmpty) {
    return null;
  }

  return Future.wait(photos.map((photo) => photo.readAsBytes()));
}

List<Map<String, dynamic>> withFirstImageFallback(List<Map<String, dynamic>> scannedItems, List<Uint8List?> images) {
  if (scannedItems.isNotEmpty) {
    return scannedItems;
  }

  return [
    {'imageBase64': base64Encode(images.whereType<Uint8List>().first)},
  ];
}

List<Map<String, dynamic>> withAllImagesFallback(List<Map<String, dynamic>> scannedItems, List<Uint8List?> images) {
  if (scannedItems.isNotEmpty) {
    return scannedItems;
  }

  return [
    {'imageBase64List': images.whereType<Uint8List>().map(base64Encode).toList()},
  ];
}

Future<List<Uint8List?>?> pickFrontAndBack(BuildContext context) async {
  final sides = await showModalBottomSheet<(Uint8List?, Uint8List?)>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => const ScanSetupSheet(),
  );

  if (sides == null) {
    return null;
  }

  return [sides.$1, sides.$2];
}

List<Map<String, dynamic>> mergeFrontAndBack(List<Map<String, dynamic>> scannedItems, List<Uint8List?> images) {
  final [frontBytes, backBytes] = images;

  return [
    {
      for (final itemFields in scannedItems) ...itemFields,
      if (frontBytes != null) 'frontImageBase64': base64Encode(frontBytes),
      if (backBytes != null) 'backImageBase64': base64Encode(backBytes),
    },
  ];
}

List<String>? documentImages(Map<String, dynamic> fields) {
  final images = [
    ...List<String>.from(fields['imageBase64List'] as List? ?? []),
    for (final key in ['imageBase64', 'frontImageBase64', 'backImageBase64'])
      if (fields[key] is String) fields[key] as String,
  ];

  return images.isEmpty ? null : images;
}

class DocumentListPage extends StatefulWidget {
  final String feature;
  final String title;
  final String emptyTitle;
  final String Function(AppLocalizations localizations) deleteConfirmText;
  final IconData icon;
  final Future<bool> Function(BuildContext context)? ensureConsent;
  final Future<List<Uint8List?>?> Function(BuildContext context) pickImages;
  final List<Map<String, dynamic>> Function(List<Map<String, dynamic>> scannedItems, List<Uint8List?> images)?
  toScannedItems;
  final DocumentSummary Function(Map<String, dynamic> fields, AppLocalizations localizations) summarize;
  final Widget Function(Map<String, dynamic>? initialFields) formBuilder;
  final Widget Function(List<Data> documents)? header;

  const DocumentListPage({
    required this.feature,
    required this.title,
    required this.emptyTitle,
    required this.deleteConfirmText,
    required this.icon,
    required this.summarize,
    required this.formBuilder,
    this.ensureConsent,
    this.toScannedItems,
    this.pickImages = pickScanImages,
    this.header,
    super.key,
  });

  @override
  State<DocumentListPage> createState() => _DocumentListPageState();
}

class _DocumentListPageState extends State<DocumentListPage> {
  List<Data> _documents = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final encryptionReady = await ensureEncryptionUnlocked(context);

    if (!encryptionReady || !mounted) {
      setState(() => _loading = false);

      return;
    }

    final cachedDocuments = await dataService.getCachedData([widget.feature]);

    if (!mounted) {
      return;
    }

    if (cachedDocuments.isNotEmpty) {
      setState(() {
        _documents = cachedDocuments;
        _loading = false;
      });
    }

    final freshResult = await dataService.getData([widget.feature]);

    if (!mounted) {
      return;
    }

    setState(() {
      _loading = false;

      if (freshResult is Success<List<Data>>) {
        _documents = freshResult.value ?? [];
      }
    });

    if (freshResult is Failure && _documents.isEmpty) {
      (freshResult as Failure).show(AppLocalizations.of(context)!);
    }
  }

  Future<Map<String, dynamic>?> _showForm([Map<String, dynamic>? initialFields]) =>
      showModalBottomSheet<Map<String, dynamic>>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (_) => widget.formBuilder(initialFields),
      );

  Future<void> _addManually() async {
    final fields = await _showForm();

    if (fields == null || !mounted) {
      return;
    }

    final saved = await ensureAndSave(context, () => dataService.saveData(Data(feature: widget.feature, fields: fields)));

    if (saved) {
      _load();
    }
  }

  Future<void> _edit(Data data) async {
    final fields = await _showForm(data.fields);

    if (fields == null || !mounted) {
      return;
    }

    final saved = await ensureAndSave(
      context,
      () => dataService.updateData(data.id!, Data(feature: widget.feature, fields: fields)),
    );

    if (saved) {
      _load();
    }
  }

  Future<void> _delete(Data data) async {
    final localizations = AppLocalizations.of(context)!;

    final confirmed = await confirmDelete(
      context,
      widget.deleteConfirmText(localizations),
      localizations.documentDeleteConfirmYes,
    );

    if (!confirmed || !mounted) {
      return;
    }

    final result = await dataService.deleteData(data.id!);

    if (!mounted) {
      return;
    }

    if (result is Failure<void>) {
      result.show(localizations);

      return;
    }

    _load();
  }

  Future<void> _scan() async {
    final hasConsent = await widget.ensureConsent!(context);

    if (!hasConsent || !mounted) {
      return;
    }

    final images = await widget.pickImages(context);

    if (images == null || images.every((image) => image == null) || !mounted) {
      return;
    }

    final localizations = AppLocalizations.of(context)!;

    showScanningDialog(context, localizations.documentScanning);

    final result = await dataService.scanImages(widget.feature, images.whereType<Uint8List>().toList());

    if (!mounted) {
      return;
    }

    Navigator.of(context).pop();

    if (result is! Success<List<Map<String, dynamic>>>) {
      (result as Failure).show(localizations);

      return;
    }

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _ScanResultSheet(
        feature: widget.feature,
        items: widget.toScannedItems!(result.value ?? [], images),
        summarize: widget.summarize,
        onSaved: _load,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final canScan = widget.ensureConsent != null;

    return Scaffold(
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : CustomScrollView(
                slivers: [
                  SliverAppBar(title: Text(widget.title), floating: true, snap: true),
                  if (_documents.isNotEmpty && widget.header != null)
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                      sliver: SliverToBoxAdapter(child: widget.header!(_documents)),
                    ),
                  if (_documents.isEmpty)
                    SliverFillRemaining(
                      child: EmptyState(
                        icon: widget.icon,
                        title: widget.emptyTitle,
                        text: localizations.emptyAddHint,
                        actions: [
                          if (canScan)
                            OutlinedButton.icon(
                              onPressed: _scan,
                              icon: const Icon(Icons.document_scanner_outlined, size: 18),
                              label: Text(localizations.documentScan),
                            ),
                          OutlinedButton.icon(
                            onPressed: _addManually,
                            icon: Icon(canScan ? Icons.edit_outlined : Icons.add, size: 18),
                            label: Text(localizations.documentAddManually),
                          ),
                        ],
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                      sliver: SliverList.builder(
                        itemCount: _documents.length,
                        itemBuilder: (context, index) {
                          final data = _documents[index];
                          final (title, details) = widget.summarize(data.fields, localizations);

                          return DocumentCard(
                            icon: widget.icon,
                            title: title,
                            details: details,
                            images: documentImages(data.fields),
                            onEdit: () => _edit(data),
                            onDelete: () => _delete(data),
                          );
                        },
                      ),
                    ),
                ],
              ),
      ),
      floatingActionButton: _loading || _documents.isEmpty
          ? null
          : !canScan
          ? FloatingActionButton(onPressed: _addManually, child: const Icon(Icons.add))
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
                  heroTag: 'scan',
                  onPressed: _scan,
                  icon: const Icon(Icons.document_scanner_outlined),
                  label: Text(localizations.documentScan),
                ),
              ],
            ),
    );
  }
}

class _ScanResultSheet extends StatefulWidget {
  final String feature;
  final List<Map<String, dynamic>> items;
  final DocumentSummary Function(Map<String, dynamic> fields, AppLocalizations localizations) summarize;
  final VoidCallback onSaved;

  const _ScanResultSheet({required this.feature, required this.items, required this.summarize, required this.onSaved});

  @override
  State<_ScanResultSheet> createState() => _ScanResultSheetState();
}

class _ScanResultSheetState extends State<_ScanResultSheet> {
  bool _saving = false;
  String? _error;

  Future<void> _saveAll() async {
    setState(() => _error = null);

    final encryptionReady = await ensureEncryptionUnlocked(context);

    if (!encryptionReady || !mounted) {
      return;
    }

    setState(() => _saving = true);

    final navigator = Navigator.of(context);

    for (final fields in widget.items) {
      final result = await dataService.saveData(Data(feature: widget.feature, fields: fields));

      if (!mounted) {
        return;
      }

      if (result is Failure<void>) {
        setState(() {
          _saving = false;
          _error = result.localizedMessage(AppLocalizations.of(context)!);
        });

        return;
      }
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
        padding: EdgeInsets.only(left: 24, right: 24, top: 24, bottom: MediaQuery.of(context).viewInsets.bottom + 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(localizations.documentScanResult, style: theme.textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(localizations.documentScanResultSubtitle, style: theme.textTheme.bodySmall),
            const SizedBox(height: 16),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  children: widget.items.map((fields) {
                    final (title, details) = widget.summarize(fields, localizations);

                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.04),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(title, style: theme.textTheme.titleSmall),
                          for (final (label, value) in details) ...[
                            const SizedBox(height: 4),
                            InfoRow(label: label, value: value),
                          ],
                        ],
                      ),
                    );
                  }).toList(),
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
            LoadingButton(loading: _saving, onPressed: _saveAll, label: localizations.documentSave),
          ],
        ),
      ),
    );
  }
}
