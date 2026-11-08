// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Patrick Zwick

import 'package:flutter/material.dart';

import '../../messages/app_localizations.dart';
import '../../model/data.dart';
import '../../model/limits.dart';
import '../../model/result.dart';
import '../../service/services.dart';
import '../../util/profile_notifier.dart';
import '../sheet/encryption_sheet.dart';
import 'document_shared.dart';

class ProfileBar extends StatefulWidget {
  final Limits limits;
  final int refreshTrigger;

  const ProfileBar({required this.limits, this.refreshTrigger = 0, super.key});

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
  void didUpdateWidget(ProfileBar oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.refreshTrigger != oldWidget.refreshTrigger) {
      _load();
    }
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

    final profiles = result.value ?? [];

    setState(() => _profiles = profiles);

    final selectedId = selectedProfileNotifier.value;

    if (profiles.isNotEmpty && profiles.every((profile) => profile.id != selectedId)) {
      final defaultId =
          profiles.where((profile) => profile.fields['isDefault'] == true).firstOrNull?.id ??
          profiles.first.id;

      if (defaultId != null) {
        await selectProfile(defaultId);
      }
    }
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

  Future<Data?> _currentProfile() async {
    final selected = _profiles
        .where((profile) => profile.id == selectedProfileNotifier.value)
        .firstOrNull;

    if (selected != null) {
      return selected;
    }

    if (_profiles.isNotEmpty) {
      return _profiles
              .where((profile) => profile.fields['isDefault'] == true)
              .firstOrNull ??
          _profiles.firstOrNull;
    }

    final localizations = AppLocalizations.of(context)!;
    final unlocked = await ensureEncryptionUnlocked(context);

    if (!unlocked || !mounted) {
      return null;
    }

    await dataService.createDefaultProfile(localizations.profileMe);
    await _load();

    return _profiles
            .where((profile) => profile.fields['isDefault'] == true)
            .firstOrNull ??
        _profiles.firstOrNull;
  }

  Future<void> _add() async {
    final name = await _askName(AppLocalizations.of(context)!.profileAdd);

    if (name == null || name.isEmpty || !mounted) {
      return;
    }

    final existingIds = _profiles.map((profile) => profile.id).toSet();
    final saved = await ensureAndSave(
      context,
      () => dataService.saveData(Data(feature: 'PROFILE', fields: {'name': name})),
    );

    if (!saved || !mounted) {
      return;
    }

    await _load();

    final addedId = _profiles
        .where((profile) => !existingIds.contains(profile.id))
        .firstOrNull
        ?.id;

    if (addedId != null) {
      await selectProfile(addedId);
    }
  }

  Future<void> _rename() async {
    final profile = await _currentProfile();

    if (profile == null || !mounted) {
      return;
    }

    final name = await _askName(
      AppLocalizations.of(context)!.profileRename,
      profile.fields['name'] as String? ?? '',
    );

    if (name == null || name.isEmpty || !mounted) {
      return;
    }

    final saved = await ensureAndSave(
      context,
      () => dataService.updateData(
        profile.id!,
        Data(feature: 'PROFILE', fields: {...profile.fields, 'name': name}),
      ),
    );

    if (saved) {
      await _load();
    }
  }

  Future<void> _delete() async {
    final localizations = AppLocalizations.of(context)!;
    final profile = await _currentProfile();

    if (profile == null || !mounted) {
      return;
    }

    final confirmed = await confirmDelete(
      context,
      localizations.profileDeleteBody(profile.fields['name'] as String? ?? ''),
      localizations.documentDeleteConfirmYes,
    );

    if (!confirmed || !mounted) {
      return;
    }

    final wasSelected = selectedProfileNotifier.value == profile.id;
    final result = await dataService.deleteProfile(profile.id!);

    if (!mounted) {
      return;
    }

    if (result is Failure<void>) {
      result.show(localizations);

      return;
    }

    if (wasSelected) {
      final remainingId = _profiles
          .where((other) => other.id != profile.id)
          .firstOrNull
          ?.id;

      if (remainingId != null) {
        await selectProfile(remainingId);
      }
    }

    await _load();
  }

  Future<void> _switchProfile() async {
    final localizations = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final selectedProfileId = selectedProfileNotifier.value;
    final canAdd = _profiles.length < widget.limits.profiles;

    final selection = await showModalBottomSheet<Object?>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
              child: Text(
                localizations.profileSwitch,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                  letterSpacing: 0.8,
                ),
              ),
            ),
            if (_profiles.isEmpty)
              ListTile(
                leading: const Icon(Icons.radio_button_checked),
                title: Text(localizations.profileMe),
                onTap: () => Navigator.of(sheetContext).pop(),
              ),
            for (final profile in _profiles)
              ListTile(
                leading: Icon(
                  profile.id == selectedProfileId
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                ),
                title: Text(profile.fields['name'] as String? ?? ''),
                onTap: () => Navigator.of(sheetContext).pop(profile),
              ),
            if (canAdd)
              ListTile(
                leading: const Icon(Icons.add),
                title: Text(localizations.profileAdd),
                onTap: () => Navigator.of(sheetContext).pop('add'),
              ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: Text(localizations.profileRename),
              onTap: () => Navigator.of(sheetContext).pop('rename'),
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: Text(
                localizations.profileDelete,
                style: const TextStyle(color: Colors.red),
              ),
              onTap: () => Navigator.of(sheetContext).pop('delete'),
            ),
          ],
        ),
      ),
    );

    if (!mounted || selection == null) {
      return;
    }

    if (selection == 'add') {
      await _add();

      return;
    }

    if (selection == 'rename') {
      await _rename();

      return;
    }

    if (selection == 'delete') {
      await _delete();

      return;
    }

    if (selection is Data) {
      await selectProfile(selection.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final selectedProfileId = selectedProfileNotifier.value;
    final selectedProfile = _profiles
        .where((profile) => profile.id == selectedProfileId)
        .firstOrNull;

    return Center(
      child: GestureDetector(
        key: const ValueKey('profile_switcher'),
        onTap: _switchProfile,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                selectedProfile?.fields['name'] as String? ??
                    localizations.profileMe,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.keyboard_arrow_down,
              size: 20,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ],
        ),
      ),
    );
  }
}
