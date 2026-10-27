// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Patrick Zwick

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../messages/app_localizations.dart';
import '../../model/result.dart';
import '../../service/services.dart';

class HealthDataConsentSheet extends StatefulWidget {
  const HealthDataConsentSheet({super.key});

  @override
  State<HealthDataConsentSheet> createState() => _HealthDataConsentSheetState();
}

class _HealthDataConsentSheetState extends State<HealthDataConsentSheet> {
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
              localizations.consentHealthDataScanTitle,
              style: theme.textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),
            Text(
              localizations.consentHealthDataScanBody,
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            RichText(
              text: TextSpan(
                style: theme.textTheme.bodySmall,
                children: [
                  TextSpan(text: localizations.consentHealthDataScanPrivacyHint),
                  const TextSpan(text: ' '),
                  TextSpan(
                    text: localizations.consentHealthDataScanPrivacyLink,
                    style: TextStyle(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w500,
                    ),
                    recognizer: TapGestureRecognizer()
                      ..onTap = () {
                        launchUrl(Uri.parse('${baseUrl}consent/health-data-scan/'));
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
                localizations.consentHealthDataScanCheckbox,
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
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Text(localizations.consentHealthDataScanConfirm),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: _loading
                  ? null
                  : () => Navigator.of(context).pop(false),
              child: Text(localizations.consentHealthDataScanDecline),
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

    final result = await consentService.giveHealthDataScanConsent();

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

Future<bool> ensureHealthDataConsent(BuildContext context) async {
  final hasConsent = await consentService.hasHealthDataScanConsent();

  if (hasConsent) {
    return true;
  }

  if (!context.mounted) {
    return false;
  }

  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    builder: (_) => const HealthDataConsentSheet(),
  );

  return result == true;
}
