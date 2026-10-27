// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Patrick Zwick

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../messages/app_localizations.dart';
import '../../service/services.dart';

Future<bool?> showPaywall(BuildContext context, {String currentTier = 'FREE'}) => showModalBottomSheet<bool>(
  context: context,
  isScrollControlled: true,
  builder: (_) => PaywallSheet(currentTier: currentTier),
);

class PaywallSheet extends StatefulWidget {
  final String currentTier;

  const PaywallSheet({super.key, required this.currentTier});

  @override
  State<PaywallSheet> createState() => _PaywallSheetState();
}

class _PaywallSheetState extends State<PaywallSheet> {
  bool _yearlyBilling = false;
  Offerings? _offerings;
  bool _loading = false;
  bool _restoring = false;

  @override
  void initState() {
    super.initState();
    _loadOfferings();
  }

  Future<void> _loadOfferings() async {
    final offerings = await subscriptionService.getOfferings();

    if (!mounted) {
      return;
    }

    setState(() => _offerings = offerings);
  }

  Future<void> _purchase(Package? package) async {
    if (package == null) {
      return;
    }

    setState(() => _loading = true);

    try {
      final success = await subscriptionService.purchase(package);

      if (!mounted) {
        return;
      }

      if (success) {
        Navigator.of(context).pop(true);
      }
    } catch (_) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context)!.failure,
            textAlign: TextAlign.center,
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _manage() async {
    final managementUrl = await subscriptionService.managementUrl();

    await launchUrl(Uri.parse(managementUrl), mode: LaunchMode.externalApplication);
  }

  Future<void> _restore() async {
    setState(() => _restoring = true);

    final restored = await subscriptionService.restore();

    if (!mounted) {
      return;
    }

    setState(() => _restoring = false);

    if (restored) {
      Navigator.of(context).pop(true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context)!.subscriptionRestoreNone,
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
  }

  Package? _findPackage([String? offeringId]) {
    final offerings = _offerings;

    if (offerings == null) {
      return null;
    }

    final offering = offeringId == null ? offerings.current : offerings.all[offeringId];

    if (offering == null) {
      return null;
    }

    if (_yearlyBilling) {
      return offering.annual;
    }

    return offering.monthly;
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Header(localizations: localizations, theme: theme),
            const SizedBox(height: 20),
            _BillingToggle(
              yearly: _yearlyBilling,
              onToggle: (yearly) => setState(() => _yearlyBilling = yearly),
              localizations: localizations,
              theme: theme,
            ),
            const SizedBox(height: 16),
            _PlanCard(
              tier: 'FREE',
              currentTier: widget.currentTier,
              localizations: localizations,
              theme: theme,
              loading: false,
              yearlyBilling: _yearlyBilling,
              onTap: null,
            ),
            const SizedBox(height: 10),
            _PlanCard(
              tier: 'PRO',
              currentTier: widget.currentTier,
              localizations: localizations,
              theme: theme,
              loading: _loading,
              yearlyBilling: _yearlyBilling,
              onTap: _loading ? null : () => _purchase(_findPackage()),
            ),
            const SizedBox(height: 10),
            _PlanCard(
              tier: 'FAMILY',
              currentTier: widget.currentTier,
              localizations: localizations,
              theme: theme,
              loading: _loading,
              yearlyBilling: _yearlyBilling,
              onTap: _loading ? null : () => _purchase(_findPackage('family')),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => launchUrl(
                Uri.parse('$baseUrl#pricing'),
                mode: LaunchMode.externalApplication,
              ),
              child: Text(localizations.subscriptionPricingPage),
            ),
            const SizedBox(height: 8),
            if (widget.currentTier != 'FREE')
              TextButton(
                key: const ValueKey('subscription_manage'),
                onPressed: _manage,
                child: Text(localizations.subscriptionManage),
              ),
            if (Platform.isIOS) ...[
              TextButton(
                onPressed: _restoring ? null : _restore,
                child: Text(
                  _restoring
                      ? '...'
                      : localizations.subscriptionRestore,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final AppLocalizations localizations;
  final ThemeData theme;

  const _Header({required this.localizations, required this.theme});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          localizations.subscriptionTitle,
          style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 6),
        Text(
          localizations.subscriptionTrialHint,
          style: theme.textTheme.bodySmall?.copyWith(
            color: Colors.green.shade600,
            fontWeight: FontWeight.w600,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _BillingToggle extends StatelessWidget {
  final bool yearly;
  final ValueChanged<bool> onToggle;
  final AppLocalizations localizations;
  final ThemeData theme;

  const _BillingToggle({
    required this.yearly,
    required this.onToggle,
    required this.localizations,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(100),
      ),
      padding: const EdgeInsets.all(3),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Expanded(child: _ToggleButton(
            label: localizations.subscriptionBillingMonthly,
            active: !yearly,
            onTap: () => onToggle(false),
            theme: theme,
          )),
          Expanded(child: _ToggleButton(
            label: localizations.subscriptionBillingYearly,
            badge: localizations.subscriptionBillingSave,
            active: yearly,
            onTap: () => onToggle(true),
            theme: theme,
          )),
        ],
      ),
    );
  }
}

class _ToggleButton extends StatelessWidget {
  final String label;
  final String? badge;
  final bool active;
  final VoidCallback onTap;
  final ThemeData theme;

  const _ToggleButton({
    required this.label,
    required this.active,
    required this.onTap,
    required this.theme,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        decoration: BoxDecoration(
          color: active ? theme.colorScheme.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(100),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: theme.textTheme.labelMedium?.copyWith(
                color: active ? Colors.white : theme.colorScheme.onSurface.withValues(alpha: 0.6),
                fontWeight: FontWeight.w600,
              ),
            ),
            if (badge != null) ...[
              const SizedBox(width: 5),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: active
                      ? Colors.white.withValues(alpha: 0.25)
                      : Colors.green.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Text(
                  badge!,
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: active ? Colors.white : Colors.green.shade700,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  final String tier;
  final String currentTier;
  final AppLocalizations localizations;
  final ThemeData theme;
  final bool loading;
  final bool yearlyBilling;
  final VoidCallback? onTap;

  const _PlanCard({
    required this.tier,
    required this.currentTier,
    required this.localizations,
    required this.theme,
    required this.loading,
    required this.yearlyBilling,
    required this.onTap,
  });

  bool get _isCurrent => tier == currentTier;

  bool get _isFree => tier == 'FREE';

  @override
  Widget build(BuildContext context) {
    final primary = theme.colorScheme.primary;
    final isHighlighted = tier == 'PRO';

    return Container(
      decoration: BoxDecoration(
        color: isHighlighted
            ? primary.withValues(alpha: 0.06)
            : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isHighlighted ? primary.withValues(alpha: 0.3) : theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
          width: isHighlighted ? 1.5 : 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: _isCurrent ? null : onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          _tierName,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: isHighlighted ? primary : null,
                          ),
                        ),
                        if (_isCurrent) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(100),
                            ),
                            child: Text(
                              localizations.subscriptionCurrentPlan,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: primary,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 6),
                    ..._features.map(
                      (f) => Padding(
                        padding: const EdgeInsets.only(top: 3),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '-  ',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                              ),
                            ),
                            Expanded(
                              child: Text(
                                f,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              _RightSide(
                tier: tier,
                isFree: _isFree,
                isCurrent: _isCurrent,
                isPrimary: isHighlighted,
                loading: loading,
                yearlyBilling: yearlyBilling,
                localizations: localizations,
                theme: theme,
                onTap: onTap,
              ),
            ],
          ),
        ),
      ),
    );
  }

  String get _tierName {
    if (_isFree) {
      return localizations.subscriptionPlanFree;
    }

    if (tier == 'FAMILY') {
      return localizations.subscriptionPlanFamily;
    }

    return localizations.subscriptionPlanPro;
  }

  List<String> get _features {
    if (_isFree) {
      return [
        localizations.subscriptionFeatureFree1,
        localizations.subscriptionFeatureFree2,
        localizations.subscriptionFeatureFree3,
        localizations.subscriptionFeatureFree4,
      ];
    }

    if (tier == 'FAMILY') {
      return [
        localizations.subscriptionFeatureFamily1,
        localizations.subscriptionFeatureFamily2,
        localizations.subscriptionFeatureFamily3,
      ];
    }

    return [
      localizations.subscriptionFeaturePro1,
      localizations.subscriptionFeaturePro2,
      localizations.subscriptionFeaturePro3,
      localizations.subscriptionFeaturePro4,
      localizations.subscriptionFeaturePro5,
      localizations.subscriptionFeaturePro6,
      localizations.subscriptionFeaturePro7,
    ];
  }
}

class _RightSide extends StatelessWidget {
  final String tier;
  final bool isFree;
  final bool isCurrent;
  final bool isPrimary;
  final bool loading;
  final bool yearlyBilling;
  final AppLocalizations localizations;
  final ThemeData theme;
  final VoidCallback? onTap;

  const _RightSide({
    required this.tier,
    required this.isFree,
    required this.isCurrent,
    required this.isPrimary,
    required this.loading,
    required this.yearlyBilling,
    required this.localizations,
    required this.theme,
    required this.onTap,
  });

  String? get _price {
    if (isFree) {
      return null;
    }

    if (tier == 'FAMILY') {
      return yearlyBilling
          ? localizations.subscriptionFamilyPriceYearly
          : localizations.subscriptionFamilyPriceMonthly;
    }

    return yearlyBilling
        ? localizations.subscriptionProPriceYearly
        : localizations.subscriptionProPriceMonthly;
  }

  @override
  Widget build(BuildContext context) {
    if (isFree || isCurrent) {
      return const SizedBox.shrink();
    }

    final price = _price;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (price != null) ...[
          Text(
            price,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
        ],
        FilledButton(
          onPressed: loading ? null : onTap,
          style: FilledButton.styleFrom(
            backgroundColor: isPrimary ? null : theme.colorScheme.secondaryContainer,
            foregroundColor: isPrimary ? null : theme.colorScheme.onSecondaryContainer,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            visualDensity: VisualDensity.compact,
          ),
          child: loading
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(localizations.subscriptionTryFree, style: const TextStyle(fontSize: 13)),
        ),
      ],
    );
  }
}
