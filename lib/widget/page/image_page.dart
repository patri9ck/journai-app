// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Patrick Zwick

import 'dart:convert';

import 'package:flutter/material.dart';

import '../../messages/app_localizations.dart';
import '../../util/document_date.dart';
import '../shared/document_list_page.dart';
import '../shared/document_shared.dart';
import '../shared/form_sheet.dart';

class ImagePage extends StatelessWidget {
  const ImagePage({super.key});

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;

    return DocumentListPage(
      feature: 'IMAGE',
      title: localizations.imagesTitle,
      emptyText: localizations.imageEmpty,
      deleteConfirmText: (localizations) => localizations.imageDeleteConfirm,
      icon: Icons.photo_outlined,
      summarize: (fields, localizations) => (
        fields['comment'] as String? ?? '',
        [
          if (fields['date'] case final String date) (localizations.vaccineDate, date),
        ],
      ),
      formBuilder: (initialFields) => _ImageFormSheet(initialFields: initialFields),
    );
  }
}

class _ImageFormSheet extends StatefulWidget {
  final Map<String, dynamic>? initialFields;

  const _ImageFormSheet({this.initialFields});

  @override
  State<_ImageFormSheet> createState() => _ImageFormSheetState();
}

class _ImageFormSheetState extends State<_ImageFormSheet> {
  late final _dateController = TextEditingController(
    text: widget.initialFields == null ? todayDocumentDate() : widget.initialFields!['date'] as String? ?? '',
  );
  late final _commentController = TextEditingController(text: widget.initialFields?['comment'] as String? ?? '');
  late String? _imageBase64 = widget.initialFields?['imageBase64'] as String?;
  bool _submitted = false;

  @override
  void dispose() {
    _dateController.dispose();
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picked = await pickDatedDocumentImages(context);

    if (picked == null || !mounted) {
      return;
    }

    final bytes = await picked.photos.first.readAsBytes();

    setState(() {
      _imageBase64 = base64Encode(bytes);
      _dateController.text = formatDocumentDate(picked.date);
    });
  }

  void _submit() {
    setState(() => _submitted = true);

    if (_imageBase64 == null) {
      return;
    }

    Navigator.of(context).pop({
      'imageBase64': _imageBase64,
      if (_dateController.text.trim().isNotEmpty) 'date': _dateController.text.trim(),
      if (_commentController.text.trim().isNotEmpty) 'comment': _commentController.text.trim(),
    });
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return FormSheet(
      title: widget.initialFields == null ? localizations.imageManualTitle : localizations.imageEditTitle,
      onSave: _submit,
      children: [
        DocumentPhotoSlot(
          label: '${localizations.imagesTitle} *',
          imageBase64: _imageBase64,
          onPick: _pickImage,
          onRemove: _imageBase64 != null ? () => setState(() => _imageBase64 = null) : null,
        ),
        if (_submitted && _imageBase64 == null) ...[
          const SizedBox(height: 4),
          Text(localizations.imageRequired, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error)),
        ],
        const SizedBox(height: 12),
        DatePickerField(controller: _dateController, labelText: localizations.vaccineDateHint),
        const SizedBox(height: 12),
        TextField(
          controller: _commentController,
          decoration: InputDecoration(labelText: localizations.imageComment),
          textCapitalization: TextCapitalization.sentences,
          minLines: 1,
          maxLines: 4,
        ),
      ],
    );
  }
}
