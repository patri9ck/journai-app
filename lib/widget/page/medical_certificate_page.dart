// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Patrick Zwick

import 'dart:convert';

import 'package:flutter/material.dart';

import '../../messages/app_localizations.dart';
import '../../model/consent_type.dart';
import '../shared/document_list_page.dart';
import '../shared/document_shared.dart';
import '../sheet/consent_sheet.dart';

class MedicalCertificatePage extends StatelessWidget {
  const MedicalCertificatePage({super.key});

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;

    return DocumentListPage(
      feature: 'MEDICAL_CERTIFICATE',
      title: localizations.medicalCertificateTitle,
      emptyText: localizations.medicalCertificateEmpty,
      deleteConfirmText: (localizations) => localizations.medicalCertificateDeleteConfirm,
      icon: Icons.description_outlined,
      ensureConsent: (context) => ensureConsent(context, ConsentType.healthDataScan),
      toScannedItems: withAllImagesFallback,
      summarize: (fields, localizations) => (
        fields['title'] as String? ?? '-',
        [
          if (fields['date'] case final String date) (localizations.medicalCertificateDate, date),
          if (fields['issuer'] case final String issuer) (localizations.medicalCertificateIssuer, issuer),
        ],
      ),
      formBuilder: (initialFields) => _CertFormSheet(initialFields: initialFields),
    );
  }
}

class _CertFormSheet extends StatefulWidget {
  final Map<String, dynamic>? initialFields;

  const _CertFormSheet({this.initialFields});

  @override
  State<_CertFormSheet> createState() => _CertFormSheetState();
}

class _CertFormSheetState extends State<_CertFormSheet> {
  late final TextEditingController _titleController;
  late final TextEditingController _dateController;
  late final TextEditingController _issuerController;
  late final TextEditingController _notesController;
  late List<String> _images;
  bool _submitted = false;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialFields ?? {};
    _titleController = TextEditingController(
      text: initial['title'] as String? ?? '',
    );
    _dateController = TextEditingController(
      text: initial['date'] as String? ?? '',
    );
    _issuerController = TextEditingController(
      text: initial['issuer'] as String? ?? '',
    );
    _notesController = TextEditingController(
      text: initial['notes'] as String? ?? '',
    );
    _images = List<String>.from(initial['imageBase64List'] as List? ?? []);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _dateController.dispose();
    _issuerController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _addImage() async {
    final photos = await pickDocumentImages(context, multipleAllowed: true);

    if (photos == null || !mounted) {
      return;
    }

    final bytesList = await Future.wait(photos.map((photo) => photo.readAsBytes()));

    setState(() {
      _images.addAll(bytesList.map(base64Encode));
    });
  }

  void _submit() {
    setState(() => _submitted = true);

    final title = _titleController.text.trim();

    if (title.isEmpty) {
      return;
    }

    Navigator.of(context).pop({
      'title': title,
      if (_dateController.text.trim().isNotEmpty)
        'date': _dateController.text.trim(),
      if (_issuerController.text.trim().isNotEmpty)
        'issuer': _issuerController.text.trim(),
      if (_notesController.text.trim().isNotEmpty)
        'notes': _notesController.text.trim(),
      if (_images.isNotEmpty) 'imageBase64List': _images,
    });
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final isEditing = widget.initialFields != null;
    final titleError = _submitted && _titleController.text.trim().isEmpty
        ? localizations.medicalCertificateTitleRequired
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
                isEditing
                    ? localizations.medicalCertificateEditTitle
                    : localizations.medicalCertificateManualTitle,
                style: theme.textTheme.headlineSmall,
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _titleController,
                decoration: InputDecoration(
                  labelText: '${localizations.medicalCertificateTitleHint} *',
                  errorText: titleError,
                ),
                textCapitalization: TextCapitalization.sentences,
              ),
              const SizedBox(height: 12),
              DatePickerField(
                controller: _dateController,
                labelText: localizations.medicalCertificateDateHint,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _issuerController,
                decoration: InputDecoration(
                  labelText: localizations.medicalCertificateIssuerHint,
                ),
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _notesController,
                decoration: InputDecoration(
                  labelText: localizations.documentNotesHint,
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              DocumentImageList(
                images: _images,
                onAddImage: _addImage,
                onRemoveImage: (index) =>
                    setState(() => _images.removeAt(index)),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _submit,
                child: Text(localizations.documentSave),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
