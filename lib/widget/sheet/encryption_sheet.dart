// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Patrick Zwick

import 'package:flutter/material.dart';

import '../../messages/app_localizations.dart';
import '../../model/result.dart';
import '../../service/services.dart';
import '../../util/storage.dart';
import '../shared/loading_button.dart';
import '../shared/form_sheet.dart';

Future<bool> ensureEncryptionUnlocked(BuildContext context) async {
  final dataKey = await storage.read(key: 'dataKey');

  if (dataKey != null) {
    return true;
  }

  if (!context.mounted) {
    return false;
  }

  var encryptedDataKey = await storage.read(key: 'encryptedDataKey');

  if (encryptedDataKey == null) {
    final encryptedDataKeyResult = await encryptionService.getEncryptedDataKey();

    if (encryptedDataKeyResult is! Success<String?>) {
      if (context.mounted) {
        (encryptedDataKeyResult as Failure<String?>).show(AppLocalizations.of(context));
      }

      return false;
    }

    encryptedDataKey = encryptedDataKeyResult.value;

    if (encryptedDataKey != null) {
      await storage.write(key: 'encryptedDataKey', value: encryptedDataKey);
    }
  }

  if (!context.mounted) {
    return false;
  }

  if (encryptedDataKey != null) {
    final keyToUnlock = encryptedDataKey;
    bool unlocked = false;
    final rootNavigator = Navigator.of(context, rootNavigator: true);

    await showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      useSafeArea: true,
      isDismissible: false,
      enableDrag: false,
      builder: (_) => EncryptionUnlockSheet(
        encryptedDataKey: keyToUnlock,
        onUnlockComplete: () {
          unlocked = true;
          rootNavigator.pop();
        },
      ),
    );

    return unlocked;
  }

  bool setupDone = false;
  final rootNavigator = Navigator.of(context, rootNavigator: true);

  await showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    useSafeArea: true,
    isDismissible: false,
    enableDrag: false,
    builder: (_) => EncryptionSetupSheet(
      onSetupComplete: () {
        setupDone = true;
        rootNavigator.pop();
      },
    ),
  );

  return setupDone;
}

class EncryptionSetupSheet extends StatefulWidget {
  final VoidCallback onSetupComplete;

  const EncryptionSetupSheet({
    required this.onSetupComplete,
    super.key,
  });

  @override
  State<EncryptionSetupSheet> createState() => _EncryptionSetupSheetState();
}

class _EncryptionSetupSheetState extends State<EncryptionSetupSheet> {
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _loading = false;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  String? _error;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return FormSheet(
      title: localizations.encryptionSetupTitle,
      subtitle: localizations.encryptionSetupBody,
      children: [
        Text(
          localizations.encryptionSetupWarning,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.error,
          ),
        ),
        const SizedBox(height: 24),
        TextField(
          controller: _passwordController,
          obscureText: _obscurePassword,
          decoration: InputDecoration(
            hintText: localizations.encryptionSetupHint,
            suffixIcon: IconButton(
              icon: Icon(_obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined),
              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
            ),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _confirmController,
          obscureText: _obscureConfirm,
          decoration: InputDecoration(
            hintText: localizations.encryptionSetupConfirmHint,
            suffixIcon: IconButton(
              icon: Icon(_obscureConfirm ? Icons.visibility_outlined : Icons.visibility_off_outlined),
              onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
            ),
          ),
          onSubmitted: (_) => _setup(),
        ),
        if (_error != null) ...[
          const SizedBox(height: 8),
          Text(_error!, style: TextStyle(color: theme.colorScheme.error, fontSize: 12)),
        ],
        const SizedBox(height: 16),
        LoadingButton(loading: _loading, onPressed: _setup, label: localizations.encryptionSetupConfirm),
      ],
    );
  }

  Future<void> _setup() async {
    final localizations = AppLocalizations.of(context)!;
    final password = _passwordController.text;
    final confirm = _confirmController.text;

    if (password.length < 8) {
      setState(() => _error = localizations.encryptionSetupPasswordTooShort);

      return;
    }

    if (password != confirm) {
      setState(() => _error = localizations.encryptionSetupPasswordMismatch);

      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    final result = await encryptionService.setupEncryption(password);

    if (!mounted) {
      return;
    }

    if (result is! Success<void>) {
      setState(() {
        _loading = false;
        _error = (result as Failure).localizedMessage(localizations);
      });

      return;
    }

    widget.onSetupComplete();
  }
}

class EncryptionUnlockSheet extends StatefulWidget {
  final String encryptedDataKey;
  final VoidCallback onUnlockComplete;

  const EncryptionUnlockSheet({
    required this.encryptedDataKey,
    required this.onUnlockComplete,
    super.key,
  });

  @override
  State<EncryptionUnlockSheet> createState() => _EncryptionUnlockSheetState();
}

class _EncryptionUnlockSheetState extends State<EncryptionUnlockSheet> {
  final _passwordController = TextEditingController();
  bool _loading = false;
  bool _wrong = false;
  bool _obscure = true;

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return FormSheet(
      title: localizations.encryptionUnlockTitle,
      subtitle: localizations.encryptionUnlockBody,
      children: [
        TextField(
          controller: _passwordController,
          obscureText: _obscure,
          autofocus: true,
          decoration: InputDecoration(
            hintText: localizations.encryptionUnlockHint,
            suffixIcon: IconButton(
              icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
              onPressed: () => setState(() => _obscure = !_obscure),
            ),
          ),
          onSubmitted: (_) => _unlock(),
        ),
        if (_wrong) ...[
          const SizedBox(height: 8),
          Text(
            localizations.encryptionUnlockWrong,
            style: TextStyle(color: theme.colorScheme.error, fontSize: 12),
          ),
        ],
        const SizedBox(height: 16),
        LoadingButton(loading: _loading, onPressed: _unlock, label: localizations.encryptionUnlockConfirm),
      ],
    );
  }

  Future<void> _unlock() async {
    final password = _passwordController.text;

    if (password.isEmpty) {
      return;
    }

    setState(() {
      _loading = true;
      _wrong = false;
    });

    final success = await cryptographyService.unlockEncryption(
      widget.encryptedDataKey,
      password,
    );

    if (!mounted) {
      return;
    }

    if (!success) {
      setState(() {
        _loading = false;
        _wrong = true;
      });

      return;
    }

    widget.onUnlockComplete();
  }
}
