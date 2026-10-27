// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Patrick Zwick

import 'dart:convert';

import 'package:flutter/material.dart';

import '../../messages/app_localizations.dart';
import '../../model/consent_type.dart';
import '../shared/document_list_page.dart';
import '../shared/document_shared.dart';
import '../shared/form_sheet.dart';
import '../sheet/consent_sheet.dart';

class VisaPage extends StatelessWidget {
  const VisaPage({super.key});

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;

    return DocumentListPage(
      feature: 'VISA',
      title: localizations.visaTitle,
      emptyText: localizations.visaEmpty,
      deleteConfirmText: (localizations) => localizations.visaDeleteConfirm,
      icon: Icons.travel_explore_outlined,
      ensureConsent: (context) => ensureConsent(context, ConsentType.documentScan),
      toScannedItems: withFirstImageFallback,
      summarize: (fields, localizations) => (
        fields['country'] as String? ?? '-',
        [
          if (fields['visaType'] case final String visaType) (localizations.visaType, visaType),
          if (fields['validUntil'] case final String validUntil) (localizations.visaValidUntil, validUntil),
        ],
      ),
      formBuilder: (initialFields) => _VisaFormSheet(initialFields: initialFields),
    );
  }
}

class _VisaFormSheet extends StatefulWidget {
  final Map<String, dynamic>? initialFields;

  const _VisaFormSheet({this.initialFields});

  @override
  State<_VisaFormSheet> createState() => _VisaFormSheetState();
}

class _VisaFormSheetState extends State<_VisaFormSheet> {
  late final TextEditingController _countryController;
  late final TextEditingController _typeController;
  late final TextEditingController _validFromController;
  late final TextEditingController _validUntilController;
  late final TextEditingController _numberController;
  late final TextEditingController _notesController;
  String? _imageBase64;
  bool _submitted = false;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialFields ?? {};
    _countryController = TextEditingController(
      text: initial['country'] as String? ?? '',
    );
    _typeController = TextEditingController(
      text: initial['visaType'] as String? ?? '',
    );
    _validFromController = TextEditingController(
      text: initial['validFrom'] as String? ?? '',
    );
    _validUntilController = TextEditingController(
      text: initial['validUntil'] as String? ?? '',
    );
    _numberController = TextEditingController(
      text: initial['visaNumber'] as String? ?? '',
    );
    _notesController = TextEditingController(
      text: initial['notes'] as String? ?? '',
    );
    _imageBase64 = initial['imageBase64'] as String?;
  }

  @override
  void dispose() {
    _countryController.dispose();
    _typeController.dispose();
    _validFromController.dispose();
    _validUntilController.dispose();
    _numberController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final photos = await pickDocumentImages(context);

    if (photos == null || !mounted) {
      return;
    }

    final bytes = await photos.first.readAsBytes();
    setState(() => _imageBase64 = base64Encode(bytes));
  }

  void _submit() {
    setState(() => _submitted = true);

    final country = _countryController.text.trim();

    if (country.isEmpty) {
      return;
    }

    Navigator.of(context).pop({
      'country': country,
      if (_typeController.text.trim().isNotEmpty)
        'visaType': _typeController.text.trim(),
      if (_validFromController.text.trim().isNotEmpty)
        'validFrom': _validFromController.text.trim(),
      if (_validUntilController.text.trim().isNotEmpty)
        'validUntil': _validUntilController.text.trim(),
      if (_numberController.text.trim().isNotEmpty)
        'visaNumber': _numberController.text.trim(),
      if (_notesController.text.trim().isNotEmpty)
        'notes': _notesController.text.trim(),
      if (_imageBase64 != null) 'imageBase64': _imageBase64,
    });
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final isEditing = widget.initialFields != null;
    final countryError = _submitted && _countryController.text.trim().isEmpty
        ? localizations.visaCountryRequired
        : null;

    return FormSheet(
      title: isEditing ? localizations.visaEditTitle : localizations.visaManualTitle,
      children: [
        TextField(
          controller: _countryController,
          decoration: InputDecoration(
            labelText: '${localizations.visaCountryHint} *',
            errorText: countryError,
          ),
          textCapitalization: TextCapitalization.words,
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _typeController,
          decoration: InputDecoration(labelText: localizations.visaTypeHint),
          textCapitalization: TextCapitalization.sentences,
        ),
        const SizedBox(height: 12),
        DatePickerField(
          controller: _validFromController,
          labelText: localizations.visaValidFromHint,
        ),
        const SizedBox(height: 12),
        DatePickerField(
          controller: _validUntilController,
          labelText: localizations.visaValidUntilHint,
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _numberController,
          decoration: InputDecoration(labelText: localizations.visaNumberHint),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _notesController,
          decoration: InputDecoration(labelText: localizations.documentNotesHint),
          maxLines: 2,
        ),
        const SizedBox(height: 16),
        DocumentPhotoSlot(
          label: localizations.documentPhotosTitle,
          imageBase64: _imageBase64,
          onPick: _pickImage,
          onRemove: _imageBase64 != null
              ? () => setState(() => _imageBase64 = null)
              : null,
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
