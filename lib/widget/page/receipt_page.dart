// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Patrick Zwick

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../messages/app_localizations.dart';
import '../../model/consent_type.dart';
import '../../model/data.dart';
import '../../model/receipt.dart';
import '../../service/services.dart';
import '../../util/document_date.dart';
import '../shared/document_list_page.dart';
import '../shared/document_shared.dart';
import '../sheet/consent_sheet.dart';
import '../shared/form_sheet.dart';

const _categories = ['DOCTOR', 'PHARMACY', 'HOSPITAL', 'OTHER'];

String _categoryName(AppLocalizations localizations, String? category) => switch (category) {
  'DOCTOR' => localizations.receiptCategoryDoctor,
  'PHARMACY' => localizations.receiptCategoryPharmacy,
  'HOSPITAL' => localizations.receiptCategoryHospital,
  _ => localizations.receiptCategoryOther,
};

class ReceiptPage extends StatelessWidget {
  const ReceiptPage({super.key});

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;

    return DocumentListPage(
      feature: 'RECEIPT',
      title: localizations.receiptTitle,
      emptyText: localizations.receiptEmpty,
      deleteConfirmText: (localizations) => localizations.receiptDeleteConfirm,
      icon: Icons.receipt_long_outlined,
      ensureConsent: (context) => ensureConsent(context, ConsentType.healthDataScan),
      toScannedItems: withFirstImageFallback,
      summarize: (fields, localizations) => (
        fields['merchant'] as String? ?? '',
        [
          if (fields['date'] case final String date) (localizations.receiptDate, date),
          if (fields['amount'] case final num amount) (localizations.receiptAmount, '$amount ${fields['currency'] ?? ''}'.trim()),
          (localizations.receiptCategory, _categoryName(localizations, fields['category'] as String?)),
        ],
      ),
      formBuilder: (initialFields) => _ReceiptFormSheet(initialFields: initialFields),
      header: (documents) => _ReceiptSummary(receipts: documents),
    );
  }
}

class _ReceiptSummary extends StatefulWidget {
  final List<Data> receipts;

  const _ReceiptSummary({required this.receipts});

  @override
  State<_ReceiptSummary> createState() => _ReceiptSummaryState();
}

class _ReceiptSummaryState extends State<_ReceiptSummary> {
  Map<String, double>? _rates;

  @override
  void initState() {
    super.initState();
    _loadRates();
  }

  Future<void> _loadRates() async {
    final rates = await currencyService.fetchRates('EUR') ?? await currencyService.getCachedRates('EUR');

    if (mounted) {
      setState(() => _rates = rates);
    }
  }

  double? _inEuro(Data receipt) => receiptAmountInEuro(receipt.fields, _rates);

  Future<void> _export(AppLocalizations localizations) async {
    final lines = [
      'date;merchant;category;amount;currency;amount_eur',
      for (final receipt in widget.receipts)
        [
          receipt.fields['date'] ?? '',
          (receipt.fields['merchant'] as String? ?? '').replaceAll(';', ','),
          receipt.fields['category'] ?? '',
          receipt.fields['amount'] ?? '',
          receipt.fields['currency'] ?? '',
          _inEuro(receipt)?.toStringAsFixed(2) ?? '',
        ].join(';'),
    ];

    final directory = await getTemporaryDirectory();
    final file = File('${directory.path}/journai-receipts.csv');

    await file.writeAsString(lines.join('\n'));

    await SharePlus.instance.share(
      ShareParams(files: [XFile(file.path, mimeType: 'text/csv')], subject: localizations.receiptTitle),
    );
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final euroAmounts = widget.receipts.map(_inEuro).toList();
    final total = euroAmounts.whereType<double>().fold(0.0, (sum, amount) => sum + amount);
    final complete = euroAmounts.every((amount) => amount != null);
    final currencyFormat = NumberFormat.currency(locale: localizations.localeName, symbol: '€');

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(localizations.receiptTotal, style: theme.textTheme.bodySmall),
                Text(
                  _rates == null ? '...' : currencyFormat.format(total),
                  style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
                if (_rates != null && !complete)
                  Text(localizations.receiptTotalIncomplete, style: theme.textTheme.bodySmall),
              ],
            ),
          ),
          OutlinedButton.icon(
            onPressed: () => _export(localizations),
            icon: const Icon(Icons.ios_share, size: 16),
            label: Text(localizations.receiptExport),
          ),
        ],
      ),
    );
  }
}

class _ReceiptFormSheet extends StatefulWidget {
  final Map<String, dynamic>? initialFields;

  const _ReceiptFormSheet({this.initialFields});

  @override
  State<_ReceiptFormSheet> createState() => _ReceiptFormSheetState();
}

class _ReceiptFormSheetState extends State<_ReceiptFormSheet> {
  late final TextEditingController _merchantController;
  late final TextEditingController _dateController;
  late final TextEditingController _amountController;
  late final TextEditingController _currencyController;
  late String _category;
  String? _imageBase64;
  bool _submitted = false;

  @override
  void initState() {
    super.initState();

    final initial = widget.initialFields ?? {};

    _merchantController = TextEditingController(text: initial['merchant'] as String? ?? '');
    _dateController = TextEditingController(
      text: widget.initialFields == null ? todayDocumentDate() : initial['date'] as String? ?? '',
    );
    _amountController = TextEditingController(text: (initial['amount'] as num?)?.toString() ?? '');
    _currencyController = TextEditingController(text: initial['currency'] as String? ?? 'EUR');
    _category = _categories.contains(initial['category']) ? initial['category'] as String : 'DOCTOR';
    _imageBase64 = initial['imageBase64'] as String?;
  }

  @override
  void dispose() {
    _merchantController.dispose();
    _dateController.dispose();
    _amountController.dispose();
    _currencyController.dispose();
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

    final merchant = _merchantController.text.trim();
    final amount = double.tryParse(_amountController.text.trim().replaceAll(',', '.'));

    if (merchant.isEmpty || amount == null) {
      return;
    }

    Navigator.of(context).pop({
      'merchant': merchant,
      'amount': amount,
      'currency': _currencyController.text.trim().toUpperCase(),
      'category': _category,
      if (_dateController.text.trim().isNotEmpty) 'date': _dateController.text.trim(),
      if (_imageBase64 != null) 'imageBase64': _imageBase64,
    });
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;

    return FormSheet(
      title: widget.initialFields != null ? localizations.receiptEditTitle : localizations.receiptManualTitle,
      onSave: _submit,
      children: [
        TextField(
          controller: _merchantController,
          decoration: InputDecoration(
            labelText: '${localizations.receiptMerchant} *',
            errorText: _submitted && _merchantController.text.trim().isEmpty ? localizations.receiptRequired : null,
          ),
          textCapitalization: TextCapitalization.words,
        ),
        const SizedBox(height: 12),
        DatePickerField(controller: _dateController, labelText: localizations.receiptDate),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              flex: 2,
              child: TextField(
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: '${localizations.receiptAmount} *',
                  errorText: _submitted && double.tryParse(_amountController.text.trim().replaceAll(',', '.')) == null
                      ? localizations.receiptRequired
                      : null,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _currencyController,
                textCapitalization: TextCapitalization.characters,
                maxLength: 3,
                decoration: InputDecoration(labelText: localizations.receiptCurrency, counterText: ''),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: _category,
          decoration: InputDecoration(labelText: localizations.receiptCategory),
          items: [
            for (final category in _categories)
              DropdownMenuItem(value: category, child: Text(_categoryName(localizations, category))),
          ],
          onChanged: (category) => setState(() => _category = category ?? _category),
        ),
        const SizedBox(height: 16),
        DocumentPhotoSlot(
          label: localizations.documentPhotosTitle,
          imageBase64: _imageBase64,
          onPick: _pickImage,
          onRemove: _imageBase64 != null ? () => setState(() => _imageBase64 = null) : null,
        ),
      ],
    );
  }
}
