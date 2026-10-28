// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Patrick Zwick

import 'dart:convert';

import 'package:flutter/material.dart';

import '../../messages/app_localizations.dart';
import '../../model/consent_type.dart';
import '../shared/document_list_page.dart';
import '../shared/document_shared.dart';
import '../sheet/consent_sheet.dart';
import '../shared/form_sheet.dart';

enum IdentityDocumentType { passport, idCard, driversLicense }

class IdentityDocumentPage extends StatelessWidget {
  final IdentityDocumentType documentType;

  const IdentityDocumentPage({super.key, required this.documentType});

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;

    return DocumentListPage(
      feature: switch (documentType) {
        IdentityDocumentType.passport => 'PASSPORT',
        IdentityDocumentType.idCard => 'ID_CARD',
        IdentityDocumentType.driversLicense => 'DRIVERS_LICENSE',
      },
      title: switch (documentType) {
        IdentityDocumentType.passport => localizations.passportTitle,
        IdentityDocumentType.idCard => localizations.idCardTitle,
        IdentityDocumentType.driversLicense => localizations.driversLicenseTitle,
      },
      emptyTitle: switch (documentType) {
        IdentityDocumentType.passport => localizations.passportEmpty,
        IdentityDocumentType.idCard => localizations.idCardEmpty,
        IdentityDocumentType.driversLicense => localizations.driversLicenseEmpty,
      },
      deleteConfirmText: (localizations) => switch (documentType) {
        IdentityDocumentType.passport => localizations.passportDeleteConfirm,
        IdentityDocumentType.idCard => localizations.idCardDeleteConfirm,
        IdentityDocumentType.driversLicense => localizations.driversLicenseDeleteConfirm,
      },
      icon: switch (documentType) {
        IdentityDocumentType.passport => Icons.book_outlined,
        IdentityDocumentType.idCard => Icons.badge_outlined,
        IdentityDocumentType.driversLicense => Icons.drive_eta_outlined,
      },
      ensureConsent: (context) => ensureConsent(context, ConsentType.documentScan),
      pickImages: pickFrontAndBack,
      toScannedItems: mergeFrontAndBack,
      summarize: _summarize,
      formBuilder: (initialFields) => _IdentityFormSheet(documentType: documentType, initialFields: initialFields),
    );
  }

  DocumentSummary _summarize(Map<String, dynamic> fields, AppLocalizations localizations) {
    final (numberKey, numberLabel) = switch (documentType) {
      IdentityDocumentType.passport => ('passportNumber', localizations.passportNumber),
      IdentityDocumentType.idCard => ('idNumber', localizations.idCardNumber),
      IdentityDocumentType.driversLicense => ('licenseNumber', localizations.driversLicenseNumber),
    };

    final name = [fields['givenNames'], fields['surname']].whereType<String>().join(' ');

    return (
      name.isNotEmpty ? name : fields[numberKey] as String? ?? '',
      [
        if (fields[numberKey] case final String number) (numberLabel, number),
        if (documentType == IdentityDocumentType.driversLicense)
          if (fields['categories'] case final String categories) (localizations.driversLicenseCategories, categories),
        if (fields['expiryDate'] case final String expiryDate)
          (
            documentType == IdentityDocumentType.passport
                ? localizations.passportExpiryDate
                : localizations.driversLicenseExpiryDate,
            expiryDate,
          ),
      ],
    );
  }
}

class _IdentityFormSheet extends StatefulWidget {
  final IdentityDocumentType documentType;
  final Map<String, dynamic>? initialFields;

  const _IdentityFormSheet({required this.documentType, this.initialFields});

  @override
  State<_IdentityFormSheet> createState() => _IdentityFormSheetState();
}

class _IdentityFormSheetState extends State<_IdentityFormSheet> {
  late final TextEditingController _numberController;
  late final TextEditingController _surnameController;
  late final TextEditingController _givenNamesController;
  late final TextEditingController _nationalityController;
  late final TextEditingController _dateOfBirthController;
  late final TextEditingController _issueDateController;
  late final TextEditingController _expiryDateController;
  late final TextEditingController _categoriesController;
  late final TextEditingController _notesController;
  String? _frontImageBase64;
  String? _backImageBase64;
  late List<String> _passportImages;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialFields ?? {};

    final numberKey = switch (widget.documentType) {
      IdentityDocumentType.passport => 'passportNumber',
      IdentityDocumentType.idCard => 'idNumber',
      IdentityDocumentType.driversLicense => 'licenseNumber',
    };

    _numberController = TextEditingController(
      text: initial[numberKey] as String? ?? '',
    );
    _surnameController = TextEditingController(
      text: initial['surname'] as String? ?? '',
    );
    _givenNamesController = TextEditingController(
      text: initial['givenNames'] as String? ?? '',
    );
    _nationalityController = TextEditingController(
      text: initial['nationality'] as String? ?? '',
    );
    _dateOfBirthController = TextEditingController(
      text: initial['dateOfBirth'] as String? ?? '',
    );
    _issueDateController = TextEditingController(
      text: initial['issueDate'] as String? ?? '',
    );
    _expiryDateController = TextEditingController(
      text: initial['expiryDate'] as String? ?? '',
    );
    _categoriesController = TextEditingController(
      text: initial['categories'] as String? ?? '',
    );
    _notesController = TextEditingController(
      text: initial['notes'] as String? ?? '',
    );
    _frontImageBase64 = initial['frontImageBase64'] as String?;
    _backImageBase64 = initial['backImageBase64'] as String?;
    _passportImages = List<String>.from(initial['imageBase64List'] as List? ?? []);
  }

  @override
  void dispose() {
    _numberController.dispose();
    _surnameController.dispose();
    _givenNamesController.dispose();
    _nationalityController.dispose();
    _dateOfBirthController.dispose();
    _issueDateController.dispose();
    _expiryDateController.dispose();
    _categoriesController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickImage({required String slot}) async {
    final photos = await pickDocumentImages(context);

    if (photos == null || !mounted) {
      return;
    }

    final bytes = await photos.first.readAsBytes();
    final base64String = base64Encode(bytes);

    setState(() {
      switch (slot) {
        case 'front':
          _frontImageBase64 = base64String;
        case 'back':
          _backImageBase64 = base64String;
      }
    });
  }

  Future<void> _addPassportImage() async {
    final photos = await pickDocumentImages(context, multipleAllowed: true);

    if (photos == null || !mounted) {
      return;
    }

    final bytesList = await Future.wait(photos.map((photo) => photo.readAsBytes()));

    setState(() {
      _passportImages.addAll(bytesList.map(base64Encode));
    });
  }

  void _submit() {
    final numberKey = switch (widget.documentType) {
      IdentityDocumentType.passport => 'passportNumber',
      IdentityDocumentType.idCard => 'idNumber',
      IdentityDocumentType.driversLicense => 'licenseNumber',
    };

    final fields = <String, dynamic>{};

    if (_numberController.text.trim().isNotEmpty) {
      fields[numberKey] = _numberController.text.trim();
    }

    if (_surnameController.text.trim().isNotEmpty) {
      fields['surname'] = _surnameController.text.trim();
    }

    if (_givenNamesController.text.trim().isNotEmpty) {
      fields['givenNames'] = _givenNamesController.text.trim();
    }

    if (_nationalityController.text.trim().isNotEmpty) {
      fields['nationality'] = _nationalityController.text.trim();
    }

    if (_dateOfBirthController.text.trim().isNotEmpty) {
      fields['dateOfBirth'] = _dateOfBirthController.text.trim();
    }

    if (_issueDateController.text.trim().isNotEmpty) {
      fields['issueDate'] = _issueDateController.text.trim();
    }

    if (_expiryDateController.text.trim().isNotEmpty) {
      fields['expiryDate'] = _expiryDateController.text.trim();
    }

    if (_categoriesController.text.trim().isNotEmpty) {
      fields['categories'] = _categoriesController.text.trim();
    }

    if (_notesController.text.trim().isNotEmpty) {
      fields['notes'] = _notesController.text.trim();
    }

    if (_frontImageBase64 != null) {
      fields['frontImageBase64'] = _frontImageBase64;
    }

    if (_backImageBase64 != null) {
      fields['backImageBase64'] = _backImageBase64;
    }

    if (_passportImages.isNotEmpty) {
      fields['imageBase64List'] = _passportImages;
    }

    Navigator.of(context).pop(fields);
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final isEditing = widget.initialFields != null;

    final title = switch (widget.documentType) {
      IdentityDocumentType.passport => isEditing
          ? localizations.passportEditTitle
          : localizations.passportManualTitle,
      IdentityDocumentType.idCard => isEditing
          ? localizations.idCardEditTitle
          : localizations.idCardManualTitle,
      IdentityDocumentType.driversLicense => isEditing
          ? localizations.driversLicenseEditTitle
          : localizations.driversLicenseManualTitle,
    };

    final numberHint = switch (widget.documentType) {
      IdentityDocumentType.passport => localizations.passportNumberHint,
      IdentityDocumentType.idCard => localizations.idCardNumberHint,
      IdentityDocumentType.driversLicense => localizations.driversLicenseNumberHint,
    };

    final isPassport =
        widget.documentType == IdentityDocumentType.passport;
    final isDriversLicense =
        widget.documentType == IdentityDocumentType.driversLicense;

    return FormSheet(
      title: title,
      onSave: _submit,
      children: [
        TextField(
          controller: _numberController,
          decoration: InputDecoration(labelText: numberHint),
          textCapitalization: TextCapitalization.characters,
        ),
        const SizedBox(height: 12),
        if (!isDriversLicense) ...[
          TextField(
            controller: _surnameController,
            decoration: InputDecoration(
              labelText: localizations.passportSurnameHint,
            ),
            textCapitalization: TextCapitalization.words,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _givenNamesController,
            decoration: InputDecoration(
              labelText: localizations.passportGivenNamesHint,
            ),
            textCapitalization: TextCapitalization.words,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _nationalityController,
            decoration: InputDecoration(
              labelText: localizations.passportNationalityHint,
            ),
            textCapitalization: TextCapitalization.words,
          ),
          const SizedBox(height: 12),
          DatePickerField(
            controller: _dateOfBirthController,
            labelText: localizations.passportDateOfBirthHint,
          ),
          const SizedBox(height: 12),
        ],
        if (isDriversLicense) ...[
          TextField(
            controller: _categoriesController,
            decoration: InputDecoration(
              labelText: localizations.driversLicenseCategoriesHint,
            ),
            textCapitalization: TextCapitalization.characters,
          ),
          const SizedBox(height: 12),
          DatePickerField(
            controller: _issueDateController,
            labelText: localizations.driversLicenseIssueDateHint,
          ),
          const SizedBox(height: 12),
        ] else ...[
          DatePickerField(
            controller: _issueDateController,
            labelText: localizations.passportIssueDateHint,
          ),
          const SizedBox(height: 12),
        ],
        DatePickerField(
          controller: _expiryDateController,
          labelText: isDriversLicense
              ? localizations.driversLicenseExpiryDateHint
              : localizations.passportExpiryDateHint,
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
        if (isPassport)
          DocumentImageList(
            images: _passportImages,
            onAddImage: _addPassportImage,
            onRemoveImage: (index) =>
                setState(() => _passportImages.removeAt(index)),
          )
        else ...[
          DocumentPhotoSlot(
            label: localizations.healthInsuranceFront,
            imageBase64: _frontImageBase64,
            onPick: () => _pickImage(slot: 'front'),
            onRemove: _frontImageBase64 != null
                ? () => setState(() => _frontImageBase64 = null)
                : null,
          ),
          const SizedBox(height: 12),
          DocumentPhotoSlot(
            label: localizations.healthInsuranceBack,
            imageBase64: _backImageBase64,
            onPick: () => _pickImage(slot: 'back'),
            onRemove: _backImageBase64 != null
                ? () => setState(() => _backImageBase64 = null)
                : null,
          ),
        ],
      ],
    );
  }
}
