// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Patrick Zwick

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../messages/app_localizations.dart';
import '../../model/result.dart';
import '../../service/services.dart';

class DocumentScanConsentSheet extends StatefulWidget {
  const DocumentScanConsentSheet({super.key});

  @override
  State<DocumentScanConsentSheet> createState() =>
      _DocumentScanConsentSheetState();
}

class _DocumentScanConsentSheetState extends State<DocumentScanConsentSheet> {
  bool _checked = false;
  bool _loading = false;
  String? _error;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              localizations.consentDocumentScanTitle,
              style: theme.textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),
            Text(
              localizations.consentDocumentScanBody,
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            RichText(
              text: TextSpan(
                style: theme.textTheme.bodySmall,
                children: [
                  TextSpan(
                    text: localizations.consentDocumentScanPrivacyHint,
                  ),
                  const TextSpan(text: ' '),
                  TextSpan(
                    text: localizations.consentDocumentScanPrivacyLink,
                    style: TextStyle(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w500,
                    ),
                    recognizer: TapGestureRecognizer()
                      ..onTap = () {
                        launchUrl(Uri.parse('${baseUrl}consent/document-scan/'));
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
                localizations.consentDocumentScanCheckbox,
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
            ElevatedButton(
              onPressed: _checked && !_loading ? _giveConsent : null,
              child: _loading
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(localizations.consentDocumentScanConfirm),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: _loading
                  ? null
                  : () => Navigator.of(context).pop(false),
              child: Text(localizations.consentDocumentScanDecline),
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

    final result = await consentService.giveDocumentScanConsent();

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

Future<bool> ensureDocumentScanConsent(BuildContext context) async {
  final hasConsent = await consentService.hasDocumentScanConsent();

  if (hasConsent) {
    return true;
  }

  if (!context.mounted) {
    return false;
  }

  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    builder: (_) => const DocumentScanConsentSheet(),
  );

  return result == true;
}
