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

class HealthInsuranceCardPage extends StatelessWidget {
  const HealthInsuranceCardPage({super.key});

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;

    return DocumentListPage(
      feature: 'HEALTH_INSURANCE_CARD',
      title: localizations.healthInsuranceCardTitle,
      emptyText: localizations.healthInsuranceCardEmpty,
      deleteConfirmText: (localizations) => localizations.healthInsuranceCardDeleteConfirm,
      icon: Icons.credit_card_outlined,
      ensureConsent: (context) => ensureConsent(context, ConsentType.documentScan),
      pickImages: pickFrontAndBack,
      toScannedItems: mergeFrontAndBack,
      summarize: (fields, localizations) => (
        fields['insuranceName'] as String? ?? '',
        [
          if (fields['memberNumber'] case final String memberNumber) (localizations.healthInsuranceMemberNumber, memberNumber),
          if (fields['validUntil'] case final String validUntil) (localizations.healthInsuranceValidUntil, validUntil),
        ],
      ),
      formBuilder: (initialFields) => _CardFormSheet(initialFields: initialFields),
    );
  }
}

class _CardFormSheet extends StatefulWidget {
  final Map<String, dynamic>? initialFields;

  const _CardFormSheet({this.initialFields});

  @override
  State<_CardFormSheet> createState() => _CardFormSheetState();
}

class _CardFormSheetState extends State<_CardFormSheet> {
  late final TextEditingController _nameController;
  late final TextEditingController _memberNumberController;
  late final TextEditingController _cardNumberController;
  late final TextEditingController _validUntilController;
  late final TextEditingController _notesController;
  String? _frontImageBase64;
  String? _backImageBase64;
  bool _submitted = false;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialFields ?? {};
    _nameController = TextEditingController(
      text: initial['insuranceName'] as String? ?? '',
    );
    _memberNumberController = TextEditingController(
      text: initial['memberNumber'] as String? ?? '',
    );
    _cardNumberController = TextEditingController(
      text: initial['cardNumber'] as String? ?? '',
    );
    _validUntilController = TextEditingController(
      text: initial['validUntil'] as String? ?? '',
    );
    _notesController = TextEditingController(
      text: initial['notes'] as String? ?? '',
    );
    _frontImageBase64 = initial['frontImageBase64'] as String?;
    _backImageBase64 = initial['backImageBase64'] as String?;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _memberNumberController.dispose();
    _cardNumberController.dispose();
    _validUntilController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickImage({required bool isFront}) async {
    final photos = await pickDocumentImages(context);

    if (photos == null || !mounted) {
      return;
    }

    final bytes = await photos.first.readAsBytes();
    final base64String = base64Encode(bytes);

    setState(() {
      if (isFront) {
        _frontImageBase64 = base64String;
      } else {
        _backImageBase64 = base64String;
      }
    });
  }

  void _submit() {
    setState(() => _submitted = true);

    final name = _nameController.text.trim();

    if (name.isEmpty) {
      return;
    }

    Navigator.of(context).pop({
      'insuranceName': name,
      if (_memberNumberController.text.trim().isNotEmpty)
        'memberNumber': _memberNumberController.text.trim(),
      if (_cardNumberController.text.trim().isNotEmpty)
        'cardNumber': _cardNumberController.text.trim(),
      if (_validUntilController.text.trim().isNotEmpty)
        'validUntil': _validUntilController.text.trim(),
      if (_notesController.text.trim().isNotEmpty)
        'notes': _notesController.text.trim(),
      if (_frontImageBase64 != null) 'frontImageBase64': _frontImageBase64,
      if (_backImageBase64 != null) 'backImageBase64': _backImageBase64,
    });
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final isEditing = widget.initialFields != null;
    final nameError = _submitted && _nameController.text.trim().isEmpty
        ? localizations.healthInsuranceNameRequired
        : null;

    return FormSheet(
      title: isEditing ? localizations.healthInsuranceCardEditTitle : localizations.healthInsuranceCardManualTitle,
      onSave: _submit,
      children: [
        TextField(
          controller: _nameController,
          decoration: InputDecoration(
            labelText: '${localizations.healthInsuranceNameHint} *',
            errorText: nameError,
          ),
          textCapitalization: TextCapitalization.words,
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _memberNumberController,
          decoration: InputDecoration(
            labelText: localizations.healthInsuranceMemberNumberHint,
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _cardNumberController,
          decoration: InputDecoration(
            labelText: localizations.healthInsuranceCardNumberHint,
          ),
        ),
        const SizedBox(height: 12),
        DatePickerField(
          controller: _validUntilController,
          labelText: localizations.healthInsuranceValidUntilHint,
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _notesController,
          decoration: InputDecoration(
            labelText: localizations.documentNotesHint,
          ),
          maxLines: 2,
        ),
        const SizedBox(height: 16),
        DocumentPhotoSlot(
          label: localizations.healthInsuranceFront,
          imageBase64: _frontImageBase64,
          onPick: () => _pickImage(isFront: true),
          onRemove: _frontImageBase64 != null
              ? () => setState(() => _frontImageBase64 = null)
              : null,
        ),
        const SizedBox(height: 12),
        DocumentPhotoSlot(
          label: localizations.healthInsuranceBack,
          imageBase64: _backImageBase64,
          onPick: () => _pickImage(isFront: false),
          onRemove: _backImageBase64 != null
              ? () => setState(() => _backImageBase64 = null)
              : null,
        ),
      ],
    );
  }
}
