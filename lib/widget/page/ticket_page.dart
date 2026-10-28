// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Patrick Zwick

import 'dart:convert';

import 'package:flutter/material.dart';

import '../../messages/app_localizations.dart';
import '../../model/consent_type.dart';
import '../../util/document_date.dart';
import '../shared/document_list_page.dart';
import '../shared/document_shared.dart';
import '../shared/form_sheet.dart';
import '../sheet/consent_sheet.dart';

class TicketPage extends StatelessWidget {
  const TicketPage({super.key});

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;

    return DocumentListPage(
      feature: 'TICKET',
      title: localizations.ticketTitle,
      emptyText: localizations.ticketEmpty,
      deleteConfirmText: (localizations) => localizations.ticketDeleteConfirm,
      icon: Icons.confirmation_number_outlined,
      ensureConsent: (context) => ensureConsent(context, ConsentType.documentScan),
      toScannedItems: withFirstImageFallback,
      summarize: (fields, localizations) => (
        fields['title'] as String? ?? '',
        [
          if (fields['date'] case final String date) (localizations.ticketDate, date),
          ...?(fields['extraFields'] as Map?)?.entries.take(2).map((entry) => ('${entry.key}', '${entry.value}')),
        ],
      ),
      formBuilder: (initialFields) => _TicketFormSheet(initialFields: initialFields),
    );
  }
}

class _TicketFormSheet extends StatefulWidget {
  final Map<String, dynamic>? initialFields;

  const _TicketFormSheet({this.initialFields});

  @override
  State<_TicketFormSheet> createState() => _TicketFormSheetState();
}

class _TicketFormSheetState extends State<_TicketFormSheet> {
  late final TextEditingController _titleController;
  late final TextEditingController _dateController;
  late final TextEditingController _notesController;
  late List<MapEntry<TextEditingController, TextEditingController>> _extraFields;
  String? _imageBase64;
  bool _submitted = false;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialFields ?? {};
    _titleController = TextEditingController(
      text: initial['title'] as String? ?? '',
    );
    _dateController = TextEditingController(
      text: widget.initialFields == null ? todayDocumentDate() : initial['date'] as String? ?? '',
    );
    _notesController = TextEditingController(
      text: initial['notes'] as String? ?? '',
    );
    _imageBase64 = initial['imageBase64'] as String?;

    _extraFields = [
      for (final entry in (initial['extraFields'] as Map? ?? {}).entries)
        MapEntry(TextEditingController(text: '${entry.key}'), TextEditingController(text: '${entry.value}')),
    ];
  }

  @override
  void dispose() {
    _titleController.dispose();
    _dateController.dispose();
    _notesController.dispose();
    for (final pair in _extraFields) {
      pair.key.dispose();
      pair.value.dispose();
    }
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

  void _addExtraField() {
    setState(() {
      _extraFields.add(MapEntry(
        TextEditingController(),
        TextEditingController(),
      ));
    });
  }

  void _removeExtraField(int index) {
    final pair = _extraFields.removeAt(index);
    pair.key.dispose();
    pair.value.dispose();
    setState(() {});
  }

  void _submit() {
    setState(() => _submitted = true);

    final title = _titleController.text.trim();

    if (title.isEmpty) {
      return;
    }

    final extraFields = <String, String>{};

    for (final pair in _extraFields) {
      final key = pair.key.text.trim();
      final value = pair.value.text.trim();

      if (key.isNotEmpty && value.isNotEmpty) {
        extraFields[key] = value;
      }
    }

    Navigator.of(context).pop({
      'title': title,
      if (_dateController.text.trim().isNotEmpty)
        'date': _dateController.text.trim(),
      if (_notesController.text.trim().isNotEmpty)
        'notes': _notesController.text.trim(),
      if (extraFields.isNotEmpty) 'extraFields': extraFields,
      if (_imageBase64 != null) 'imageBase64': _imageBase64,
    });
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final isEditing = widget.initialFields != null;
    final titleError = _submitted && _titleController.text.trim().isEmpty
        ? localizations.ticketTitleRequired
        : null;

    return FormSheet(
      title: isEditing ? localizations.ticketEditTitle : localizations.ticketManualTitle,
      onSave: _submit,
      children: [
        TextField(
          controller: _titleController,
          decoration: InputDecoration(
            labelText: '${localizations.ticketTitleHint} *',
            errorText: titleError,
          ),
          textCapitalization: TextCapitalization.sentences,
        ),
        const SizedBox(height: 12),
        DatePickerField(
          controller: _dateController,
          labelText: localizations.ticketDateHint,
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _notesController,
          decoration: InputDecoration(labelText: localizations.documentNotesHint),
          maxLines: 2,
        ),
        const SizedBox(height: 16),
        ..._extraFields.asMap().entries.map((entry) {
          final index = entry.key;
          final pair = entry.value;

          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: pair.key,
                    decoration: InputDecoration(
                      labelText: localizations.ticketFieldName,
                    ),
                    textCapitalization: TextCapitalization.sentences,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: pair.value,
                    decoration: InputDecoration(
                      labelText: localizations.ticketFieldValue,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: () => _removeExtraField(index),
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                  constraints: const BoxConstraints(),
                  padding: const EdgeInsets.all(8),
                ),
              ],
            ),
          );
        }),
        TextButton.icon(
          onPressed: _addExtraField,
          icon: const Icon(Icons.add, size: 18),
          label: Text(localizations.ticketAddField),
        ),
        const SizedBox(height: 8),
        DocumentPhotoSlot(
          label: localizations.documentPhotosTitle,
          imageBase64: _imageBase64,
          onPick: _pickImage,
          onRemove: _imageBase64 != null
              ? () => setState(() => _imageBase64 = null)
              : null,
        ),
      ],
    );
  }
}
