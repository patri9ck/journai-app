// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Patrick Zwick

import 'dart:convert';
import 'dart:typed_data';

import 'package:exif/exif.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart' show ImagePicker, ImageSource, XFile;

import '../../messages/app_localizations.dart';
import '../../model/result.dart';
import '../../util/document_date.dart';
import '../sheet/encryption_sheet.dart';
import 'form_sheet.dart';

Future<List<XFile>?> pickDocumentImages(
  BuildContext context, {
  bool multipleAllowed = false,
}) async => (await _pickDocumentImages(context, multipleAllowed: multipleAllowed))?.photos;

Future<({List<XFile> photos, DateTime date})?> pickDatedDocumentImages(
  BuildContext context, {
  bool multipleAllowed = false,
}) async {
  final picked = await _pickDocumentImages(context, multipleAllowed: multipleAllowed);

  if (picked == null) {
    return null;
  }

  if (picked.source == ImageSource.camera) {
    return (photos: picked.photos, date: DateTime.now());
  }

  return (photos: picked.photos, date: await _captureDate(picked.photos.first) ?? DateTime.now());
}

Future<DateTime?> _captureDate(XFile photo) async {
  final tags = await readExifFromBytes(await photo.readAsBytes());
  final value = (tags['EXIF DateTimeOriginal'] ?? tags['Image DateTime'])?.printable;
  final match = RegExp(r'^(\d{4}):(\d{2}):(\d{2})').firstMatch(value ?? '');

  if (match == null) {
    return null;
  }

  return DateTime(int.parse(match.group(1)!), int.parse(match.group(2)!), int.parse(match.group(3)!));
}

Future<({ImageSource source, List<XFile> photos})?> _pickDocumentImages(
  BuildContext context, {
  bool multipleAllowed = false,
}) async {
  final localizations = AppLocalizations.of(context)!;

  final source = await showModalBottomSheet<ImageSource>(
    context: context,
    builder: (_) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.camera_alt_outlined),
            title: Text(localizations.documentPickCamera),
            onTap: () => Navigator.of(context).pop(ImageSource.camera),
          ),
          ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: Text(localizations.documentPickGallery),
            onTap: () => Navigator.of(context).pop(ImageSource.gallery),
          ),
        ],
      ),
    ),
  );

  if (source == null) {
    return null;
  }

  final picker = ImagePicker();

  if (source == ImageSource.camera || !multipleAllowed) {
    final photo = await picker.pickImage(
      source: source,
      imageQuality: 80,
      maxWidth: 1600,
    );

    if (photo == null) {
      return null;
    }

    return (source: source, photos: [photo]);
  } else {
    final photos = await picker.pickMultiImage(imageQuality: 80, maxWidth: 1600);

    if (photos.isEmpty) {
      return null;
    }

    return (source: source, photos: photos);
  }
}

Uint8List? tryDecodeBase64(String? value) {
  if (value == null) {
    return null;
  }

  try {
    return base64Decode(value);
  } on FormatException {
    return null;
  }
}

final _decodedImages = <String, Uint8List>{};

Uint8List? _decodeImage(String imageBase64) {
  final cachedBytes = _decodedImages.remove(imageBase64);

  if (cachedBytes != null) {
    _decodedImages[imageBase64] = cachedBytes;

    return cachedBytes;
  }

  final bytes = tryDecodeBase64(imageBase64);

  if (bytes == null) {
    return null;
  }

  if (_decodedImages.length >= 30) {
    _decodedImages.remove(_decodedImages.keys.first);
  }

  _decodedImages[imageBase64] = bytes;

  return bytes;
}

int _cacheSize(BuildContext context, double size) {
  return (size * MediaQuery.devicePixelRatioOf(context)).round();
}

class DocumentPhotoSlot extends StatelessWidget {
  final String label;
  final String? imageBase64;
  final VoidCallback onPick;
  final VoidCallback? onRemove;

  const DocumentPhotoSlot({
    super.key,
    required this.label,
    required this.imageBase64,
    required this.onPick,
    this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final labelStyle = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: labelStyle),
        const SizedBox(height: 4),
        if (imageBase64 != null)
          _ImagePreview(
            imageBase64: imageBase64!,
            onEdit: onPick,
            onRemove: onRemove,
          )
        else
          _EmptySlot(onPick: onPick),
      ],
    );
  }
}

class _ImagePreview extends StatelessWidget {
  final String imageBase64;
  final VoidCallback onEdit;
  final VoidCallback? onRemove;

  const _ImagePreview({
    required this.imageBase64,
    required this.onEdit,
    this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final bytes = _decodeImage(imageBase64);

    return Stack(
      children: [
        GestureDetector(
          onTap: bytes != null ? () => _openFullscreen(context, imageBase64) : null,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: bytes != null
                ? Image.memory(
                    bytes,
                    height: 120,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  )
                : Container(
                    height: 120,
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    child: const Icon(Icons.broken_image_outlined),
                  ),
          ),
        ),
        Positioned(
          top: 6,
          right: 6,
          child: Row(
            children: [
              _OverlayIconButton(icon: Icons.edit_outlined, onTap: onEdit),
              if (onRemove != null) ...[
                const SizedBox(width: 4),
                _OverlayIconButton(icon: Icons.close, onTap: onRemove!),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _EmptySlot extends StatelessWidget {
  final VoidCallback onPick;

  const _EmptySlot({required this.onPick});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: onPick,
      child: Container(
        height: 80,
        decoration: BoxDecoration(
          border: Border.all(
            color: theme.colorScheme.outline.withValues(alpha: 0.5),
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Icon(
            Icons.add_photo_alternate_outlined,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
          ),
        ),
      ),
    );
  }
}

class _OverlayIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _OverlayIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Colors.black54,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Icon(icon, size: 16, color: Colors.white),
      ),
    );
  }
}

class DocumentImageList extends StatelessWidget {
  final List<String> images;
  final VoidCallback onAddImage;
  final void Function(int index) onRemoveImage;

  const DocumentImageList({
    super.key,
    required this.images,
    required this.onAddImage,
    required this.onRemoveImage,
  });

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          localizations.documentPhotosTitle,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ...images.asMap().entries.map(
              (entry) => _ThumbnailChip(
                imageBase64: entry.value,
                onRemove: () => onRemoveImage(entry.key),
              ),
            ),
            _AddThumbnailChip(onTap: onAddImage),
          ],
        ),
      ],
    );
  }
}

class _ThumbnailChip extends StatelessWidget {
  final String imageBase64;
  final VoidCallback onRemove;

  const _ThumbnailChip({required this.imageBase64, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bytes = _decodeImage(imageBase64);

    return SizedBox(
      width: 80,
      height: 80,
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: bytes != null
                ? Image.memory(
                    bytes,
                    width: 80,
                    height: 80,
                    cacheWidth: _cacheSize(context, 80),
                    fit: BoxFit.cover,
                  )
                : Container(
                    width: 80,
                    height: 80,
                    color: theme.colorScheme.surfaceContainerHighest,
                    child: const Icon(Icons.broken_image_outlined, size: 20),
                  ),
          ),
          Positioned(
            top: 2,
            right: 2,
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

class _AddThumbnailChip extends StatelessWidget {
  final VoidCallback onTap;

  const _AddThumbnailChip({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          border: Border.all(
            color: theme.colorScheme.outline.withValues(alpha: 0.5),
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          Icons.add_photo_alternate_outlined,
          color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
          size: 24,
        ),
      ),
    );
  }
}

class InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const InfoRow({super.key, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final labelStyle = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
    );

    return RichText(
      text: TextSpan(
        children: [
          TextSpan(text: '$label: ', style: labelStyle),
          TextSpan(text: value, style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }
}

void _openFullscreen(BuildContext context, String imageBase64) {
  final bytes = _decodeImage(imageBase64);

  if (bytes == null) {
    return;
  }

  Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => _FullscreenImagePage(imageBytes: bytes),
    ),
  );
}

class _FullscreenImagePage extends StatelessWidget {
  final Uint8List imageBytes;

  const _FullscreenImagePage({required this.imageBytes});

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
          child: Image.memory(imageBytes, fit: BoxFit.contain),
        ),
      ),
    );
  }
}

class DocumentCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final List<(String, String)> details;
  final List<String>? images;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const DocumentCard({
    super.key,
    required this.icon,
    required this.title,
    this.details = const [],
    this.images,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: theme.colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    icon,
                    color: theme.colorScheme.primary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: theme.textTheme.titleSmall),
                      ...details.map(
                        (detail) => Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: InfoRow(label: detail.$1, value: detail.$2),
                        ),
                      ),
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
            if (images != null && images!.isNotEmpty) ...[
              const SizedBox(height: 8),
              SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: images!.map((imageBase64) {
                      final bytes = _decodeImage(imageBase64);

                      return Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: GestureDetector(
                          onTap: () => _openFullscreen(context, imageBase64),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: bytes != null
                                ? Image.memory(
                                    bytes,
                                    width: 80,
                                    height: 52,
                                    cacheWidth: _cacheSize(context, 80),
                                    fit: BoxFit.cover,
                                  )
                                : Container(
                                    width: 80,
                                    height: 52,
                                    color: theme.colorScheme.surfaceContainerHighest,
                                    child: const Icon(
                                      Icons.broken_image_outlined,
                                      size: 16,
                                    ),
                                  ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

Future<bool> ensureAndSave(
  BuildContext context,
  Future<Result<void>> Function() action,
) async {
  final encryptionReady = await ensureEncryptionUnlocked(context);

  if (!encryptionReady || !context.mounted) {
    return false;
  }

  final result = await action();

  if (!context.mounted) {
    return false;
  }

  if (result is Failure<void>) {
    result.show(AppLocalizations.of(context)!);

    return false;
  }

  return true;
}

class DatePickerField extends StatefulWidget {
  final TextEditingController controller;
  final String labelText;

  const DatePickerField({
    super.key,
    required this.controller,
    required this.labelText,
  });

  @override
  State<DatePickerField> createState() => _DatePickerFieldState();
}

class _DatePickerFieldState extends State<DatePickerField> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    setState(() {});
  }

  Future<void> _pickDate() async {
    DateTime? initial;
    final text = widget.controller.text.trim();

    if (text.isNotEmpty) {
      try {
        final parts = text.split('.');
        if (parts.length == 3) {
          initial = DateTime(
            int.parse(parts[2]),
            int.parse(parts[1]),
            int.parse(parts[0]),
          );
        }
      } on FormatException {
        initial = null;
      }
    }

    final picked = await showDatePicker(
      context: context,
      initialDate: initial ?? DateTime.now(),
      firstDate: DateTime(1900),
      lastDate: DateTime(2100),
    );

    if (picked != null) {
      widget.controller.text = formatDocumentDate(picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasValue = widget.controller.text.isNotEmpty;

    return TextField(
      controller: widget.controller,
      readOnly: true,
      decoration: InputDecoration(
        labelText: widget.labelText,
        suffixIcon: hasValue
            ? IconButton(
                icon: const Icon(Icons.close, size: 18),
                onPressed: () => widget.controller.clear(),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              )
            : const Icon(Icons.calendar_today_outlined, size: 18),
      ),
      onTap: _pickDate,
    );
  }
}

class ScanSetupSheet extends StatefulWidget {
  const ScanSetupSheet({super.key});

  @override
  State<ScanSetupSheet> createState() => _ScanSetupSheetState();
}

class _ScanSetupSheetState extends State<ScanSetupSheet> {
  Uint8List? _frontBytes;
  Uint8List? _backBytes;
  String? _frontBase64;
  String? _backBase64;

  Future<void> _pickFront() async {
    final photos = await pickDocumentImages(context);

    if (photos == null || !mounted) {
      return;
    }

    final bytes = await photos.first.readAsBytes();

    setState(() {
      _frontBytes = bytes;
      _frontBase64 = base64Encode(bytes);
    });
  }

  Future<void> _pickBack() async {
    final photos = await pickDocumentImages(context);

    if (photos == null || !mounted) {
      return;
    }

    final bytes = await photos.first.readAsBytes();

    setState(() {
      _backBytes = bytes;
      _backBase64 = base64Encode(bytes);
    });
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final canScan = _frontBytes != null || _backBytes != null;

    return FormSheet(
      title: localizations.documentScanSetupTitle,
      subtitle: localizations.documentScanSetupSubtitle,
      children: [
        Row(
          children: [
            Expanded(
              child: DocumentPhotoSlot(
                label: localizations.documentScanFront,
                imageBase64: _frontBase64,
                onPick: _pickFront,
                onRemove: _frontBytes != null
                    ? () => setState(() {
                          _frontBytes = null;
                          _frontBase64 = null;
                        })
                    : null,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: DocumentPhotoSlot(
                label: localizations.documentScanBack,
                imageBase64: _backBase64,
                onPick: _pickBack,
                onRemove: _backBytes != null
                    ? () => setState(() {
                          _backBytes = null;
                          _backBase64 = null;
                        })
                    : null,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        ElevatedButton(
          onPressed: canScan
              ? () => Navigator.of(context).pop((_frontBytes, _backBytes))
              : null,
          child: Text(localizations.documentScan),
        ),
      ],
    );
  }
}

Future<bool> confirmDelete(
  BuildContext context,
  String message,
  String confirmLabel,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) {
      final theme = Theme.of(context);
      final localizations = AppLocalizations.of(context)!;
      return Dialog(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(message, style: theme.textTheme.bodyMedium),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: Text(localizations.back),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    child: Text(
                      confirmLabel,
                      style: TextStyle(color: theme.colorScheme.error),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );

  return confirmed == true;
}

class OverLimitBanner extends StatelessWidget {
  final String featureName;
  final VoidCallback onUpgrade;

  const OverLimitBanner({
    super.key,
    required this.featureName,
    required this.onUpgrade,
  });

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(
              Icons.warning_amber_rounded,
              size: 18,
              color: Colors.orange.shade700,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  localizations.overLimitBanner(featureName),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 6),
                GestureDetector(
                  onTap: onUpgrade,
                  child: Text(
                    localizations.settingsSubscriptionUpgrade,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
