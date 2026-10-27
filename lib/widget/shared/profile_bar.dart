// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Patrick Zwick

import 'package:flutter/material.dart';

import '../../messages/app_localizations.dart';
import '../../model/data.dart';
import '../../model/limits.dart';
import '../../model/result.dart';
import '../../service/services.dart';
import '../../util/profile_notifier.dart';
import 'document_shared.dart';

class ProfileBar extends StatefulWidget {
  final Limits limits;

  const ProfileBar({required this.limits, super.key});

  @override
  State<ProfileBar> createState() => _ProfileBarState();
}

class _ProfileBarState extends State<ProfileBar> {
  List<Data> _profiles = [];

  @override
  void initState() {
    super.initState();
    selectedProfileNotifier.addListener(_onProfileChanged);
    _load();
  }

  @override
  void dispose() {
    selectedProfileNotifier.removeListener(_onProfileChanged);
    super.dispose();
  }

  void _onProfileChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _load() async {
    final cached = await dataService.getCachedData(['PROFILE']);

    if (!mounted) {
      return;
    }

    setState(() => _profiles = cached);

    final result = await dataService.getData(['PROFILE']);

    if (!mounted || result is! Success<List<Data>>) {
      return;
    }

    setState(() => _profiles = result.value ?? []);
  }

  Future<String?> _askName(String title, [String initialName = '']) {
    final localizations = AppLocalizations.of(context)!;
    final controller = TextEditingController(text: initialName);

    return showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(hintText: localizations.profileName),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(localizations.back),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(controller.text.trim()),
            child: Text(localizations.profileSave),
          ),
        ],
      ),
    );
  }

  Future<void> _add() async {
    final name = await _askName(AppLocalizations.of(context)!.profileAdd);

    if (name == null || name.isEmpty || !mounted) {
      return;
    }

    final saved = await ensureAndSave(
      context,
      () => dataService.saveData(Data(feature: 'PROFILE', fields: {'name': name})),
    );

    if (saved) {
      await _load();
    }
  }

  Future<void> _edit(Data profile) async {
    final localizations = AppLocalizations.of(context)!;

    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: Text(localizations.profileRename),
              onTap: () => Navigator.of(sheetContext).pop('rename'),
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: Text(localizations.profileDelete, style: const TextStyle(color: Colors.red)),
              onTap: () => Navigator.of(sheetContext).pop('delete'),
            ),
          ],
        ),
      ),
    );

    if (!mounted) {
      return;
    }

    if (action == 'rename') {
      await _rename(profile);
    }

    if (action == 'delete') {
      await _delete(profile);
    }
  }

  Future<void> _rename(Data profile) async {
    final name = await _askName(
      AppLocalizations.of(context)!.profileRename,
      profile.fields['name'] as String? ?? '',
    );

    if (name == null || name.isEmpty || !mounted) {
      return;
    }

    final saved = await ensureAndSave(
      context,
      () => dataService.updateData(profile.id!, Data(feature: 'PROFILE', fields: {'name': name})),
    );

    if (saved) {
      await _load();
    }
  }

  Future<void> _delete(Data profile) async {
    final localizations = AppLocalizations.of(context)!;
    final name = profile.fields['name'] as String? ?? '';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(localizations.profileDelete),
        content: Text(localizations.profileDeleteBody(name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(localizations.back),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(localizations.profileDelete, style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) {
      return;
    }

    if (selectedProfileNotifier.value == profile.id) {
      await selectProfile(null);
    }

    final result = await dataService.deleteProfile(profile.id!);

    if (!mounted) {
      return;
    }

    if (result is Failure<void>) {
      result.show(localizations);
    }

    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final selectedProfileId = selectedProfileNotifier.value;
    final canAdd = _profiles.length < widget.limits.profiles - 1;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          ChoiceChip(
            label: Text(localizations.profileMe),
            selected: selectedProfileId == null,
            onSelected: (_) => selectProfile(null),
          ),
          for (final profile in _profiles) ...[
            const SizedBox(width: 8),
            GestureDetector(
              onLongPress: () => _edit(profile),
              child: ChoiceChip(
                label: Text(profile.fields['name'] as String? ?? ''),
                selected: selectedProfileId == profile.id,
                onSelected: (_) => selectProfile(profile.id),
              ),
            ),
          ],
          if (canAdd) ...[
            const SizedBox(width: 8),
            ActionChip(
              avatar: const Icon(Icons.add, size: 18),
              label: Text(localizations.profileAdd),
              onPressed: _add,
            ),
          ],
        ],
      ),
    );
  }
}
