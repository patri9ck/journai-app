// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Patrick Zwick

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../messages/app_localizations.dart';
import '../../model/consent_type.dart';
import '../../model/result.dart';
import '../../service/services.dart';
import '../shared/loading_button.dart';

class ConsentSheet extends StatefulWidget {
  final ConsentType type;

  const ConsentSheet({required this.type, super.key});

  @override
  State<ConsentSheet> createState() => _ConsentSheetState();
}

class _ConsentSheetState extends State<ConsentSheet> {
  bool _checked = false;
  bool _loading = false;
  String? _error;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final isHealthDataScan = widget.type == ConsentType.healthDataScan;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              isHealthDataScan ? localizations.consentHealthDataScanTitle : localizations.consentDocumentScanTitle,
              style: theme.textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),
            Text(
              isHealthDataScan ? localizations.consentHealthDataScanBody : localizations.consentDocumentScanBody,
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            RichText(
              text: TextSpan(
                style: theme.textTheme.bodySmall,
                children: [
                  TextSpan(text: localizations.consentPrivacyHint),
                  const TextSpan(text: ' '),
                  TextSpan(
                    text: localizations.consentPrivacyLink,
                    style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.w500),
                    recognizer: TapGestureRecognizer()
                      ..onTap = () {
                        launchUrl(Uri.parse('${baseUrl}consent/${widget.type.pagePath}/'));
                      },
                  ),
                  const TextSpan(text: '.'),
                ],
              ),
            ),
            const SizedBox(height: 16),
            CheckboxListTile(
              value: _checked,
              onChanged: (value) {
                setState(() => _checked = value ?? false);
              },
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
              title: Text(
                isHealthDataScan
                    ? localizations.consentHealthDataScanCheckbox
                    : localizations.consentDocumentScanCheckbox,
                style: theme.textTheme.bodySmall,
              ),
            ),
            const SizedBox(height: 16),
            if (_error != null) ...[
              Text(
                _error!,
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
            ],
            LoadingButton(
              loading: _loading,
              onPressed: _checked ? _giveConsent : null,
              label: localizations.consentConfirm,
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: _loading ? null : () => Navigator.of(context).pop(false),
              child: Text(localizations.consentDecline),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _giveConsent() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final result = await consentService.giveConsent(widget.type);

    if (!mounted) {
      return;
    }

    if (result is Failure<void>) {
      setState(() {
        _loading = false;
        _error = result.localizedMessage(AppLocalizations.of(context));
      });

      return;
    }

    Navigator.of(context).pop(true);
  }
}

Future<bool> ensureConsent(BuildContext context, ConsentType type) async {
  final hasConsent = await consentService.hasConsent(type);

  if (hasConsent) {
    return true;
  }

  if (!context.mounted) {
    return false;
  }

  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => ConsentSheet(type: type),
  );

  return result == true;
}
