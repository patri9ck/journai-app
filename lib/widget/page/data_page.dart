// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Patrick Zwick

import 'package:flutter/material.dart';

import '../../messages/app_localizations.dart';
import '../../model/data.dart';
import '../../model/limits.dart';
import '../../model/result.dart';
import '../../service/services.dart';
import '../../util/auth_scope.dart';
import '../../util/profile_notifier.dart';
import '../shared/profile_bar.dart';
import '../shared/tier_badge.dart';
import 'allergy_page.dart';
import 'condition_page.dart';
import 'health_insurance_card_page.dart';
import 'health_value_page.dart';
import 'identity_document_page.dart';
import 'image_page.dart';
import 'medical_certificate_page.dart';
import 'receipt_page.dart';
import 'ticket_page.dart';
import 'vaccine_page.dart';
import 'visa_page.dart';

class DataPage extends StatefulWidget {
  const DataPage({super.key});

  @override
  State<DataPage> createState() => _DataPageState();
}

class _DataPageState extends State<DataPage> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  final Map<String, int> _entryCounts = {};
  Limits _limits = Limits.unlimited;

  @override
  void initState() {
    super.initState();
    selectedProfileNotifier.addListener(_loadAll);
    _loadAll();
  }

  @override
  void dispose() {
    selectedProfileNotifier.removeListener(_loadAll);
    super.dispose();
  }

  Future<void> _loadAll() async {
    final limits = await limitsService.getLimits();

    if (!limits.hasProfiles && selectedProfileNotifier.value != null) {
      await selectProfile(null);

      return;
    }

    final allDataResult = await dataService.getData();

    if (!mounted) {
      return;
    }

    setState(() => _limits = limits);

    if (allDataResult is Success<List<Data>>) {
      final all = allDataResult.value ?? [];
      final counts = <String, int>{};

      for (final entry in all) {
        counts[entry.feature] = (counts[entry.feature] ?? 0) + 1;
      }

      setState(() {
        _entryCounts
          ..clear()
          ..addAll(counts);
      });
    }
  }

  VoidCallback? _onTap(bool enabled, Future<void> Function() navigate) {
    if (!enabled) {
      return null;
    }

    return () async {
      await navigate();
      _loadAll();
    };
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final localizations = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final isLoggedIn = AuthScope.of(context);

    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            if (isLoggedIn && _limits.hasProfiles)
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                sliver: SliverToBoxAdapter(child: ProfileBar(limits: _limits)),
              ),
            _sectionHeader(localizations.dataSectionHealthHeader, theme),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  _SectionTile(
                    key: const ValueKey('data_vaccinations'),
                    icon: Icons.vaccines_outlined,
                    title: localizations.dataSectionVaccines,
                    subtitle: localizations.dataSectionVaccinesSubtitle,
                    count: _entryCounts['VACCINE'] ?? 0,
                    enabled: isLoggedIn && _limits.vaccinesEnabled,
                    loginRequired: !isLoggedIn,
                    onTap: _onTap(
                      isLoggedIn && _limits.vaccinesEnabled,
                      () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const VaccinePage()),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  _SectionTile(
                    icon: Icons.description_outlined,
                    title: localizations.dataSectionMedicalCertificates,
                    subtitle: localizations.dataSectionMedicalCertificatesSubtitle,
                    count: _entryCounts['MEDICAL_CERTIFICATE'] ?? 0,
                    enabled: isLoggedIn && _limits.isFeatureEnabled('MEDICAL_CERTIFICATE'),
                    loginRequired: !isLoggedIn,
                    onTap: _onTap(
                      isLoggedIn && _limits.isFeatureEnabled('MEDICAL_CERTIFICATE'),
                      () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const MedicalCertificatePage(),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  _SectionTile(
                    icon: Icons.warning_amber_outlined,
                    title: localizations.dataSectionAllergies,
                    subtitle: localizations.dataSectionAllergiesSubtitle,
                    count: _entryCounts['ALLERGY'] ?? 0,
                    enabled: isLoggedIn && _limits.isFeatureEnabled('ALLERGY'),
                    loginRequired: !isLoggedIn,
                    onTap: _onTap(
                      isLoggedIn && _limits.isFeatureEnabled('ALLERGY'),
                      () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const AllergyPage()),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  _SectionTile(
                    icon: Icons.medical_information_outlined,
                    title: localizations.dataSectionConditions,
                    subtitle: localizations.dataSectionConditionsSubtitle,
                    count: _entryCounts['CONDITION'] ?? 0,
                    enabled: isLoggedIn && _limits.isFeatureEnabled('CONDITION'),
                    loginRequired: !isLoggedIn,
                    onTap: _onTap(
                      isLoggedIn && _limits.isFeatureEnabled('CONDITION'),
                      () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const ConditionPage()),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  _SectionTile(
                    icon: Icons.monitor_heart_outlined,
                    title: localizations.dataSectionHealthValues,
                    subtitle: localizations.dataSectionHealthValuesSubtitle,
                    count: Limits.healthValueFeatures.fold(
                      0,
                      (sum, cat) => sum + (_entryCounts[cat] ?? 0),
                    ),
                    enabled: isLoggedIn && _limits.isAnyHealthValueEnabled,
                    loginRequired: !isLoggedIn,
                    onTap: _onTap(
                      isLoggedIn && _limits.isAnyHealthValueEnabled,
                      () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const HealthValuePage(),
                        ),
                      ),
                    ),
                  ),
                ]),
              ),
            ),
            _sectionHeader(localizations.dataSectionDocumentsHeader, theme),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  _SectionTile(
                    icon: Icons.credit_card_outlined,
                    title: localizations.dataSectionHealthInsuranceCards,
                    subtitle: localizations.dataSectionHealthInsuranceCardsSubtitle,
                    count: _entryCounts['HEALTH_INSURANCE_CARD'] ?? 0,
                    enabled: isLoggedIn && _limits.isFeatureEnabled('HEALTH_INSURANCE_CARD'),
                    loginRequired: !isLoggedIn,
                    onTap: _onTap(
                      isLoggedIn && _limits.isFeatureEnabled('HEALTH_INSURANCE_CARD'),
                      () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const HealthInsuranceCardPage(),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  _SectionTile(
                    icon: Icons.badge_outlined,
                    title: localizations.dataSectionIdCards,
                    subtitle: localizations.dataSectionIdCardsSubtitle,
                    count: _entryCounts['ID_CARD'] ?? 0,
                    enabled: isLoggedIn && _limits.isFeatureEnabled('ID_CARD'),
                    loginRequired: !isLoggedIn,
                    onTap: _onTap(
                      isLoggedIn && _limits.isFeatureEnabled('ID_CARD'),
                      () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const IdentityDocumentPage(
                            documentType: IdentityDocumentType.idCard,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  _SectionTile(
                    icon: Icons.book_outlined,
                    title: localizations.dataSectionPassports,
                    subtitle: localizations.dataSectionPassportsSubtitle,
                    count: _entryCounts['PASSPORT'] ?? 0,
                    enabled: isLoggedIn && _limits.isFeatureEnabled('PASSPORT'),
                    loginRequired: !isLoggedIn,
                    onTap: _onTap(
                      isLoggedIn && _limits.isFeatureEnabled('PASSPORT'),
                      () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const IdentityDocumentPage(
                            documentType: IdentityDocumentType.passport,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  _SectionTile(
                    icon: Icons.drive_eta_outlined,
                    title: localizations.dataSectionDriversLicenses,
                    subtitle: localizations.dataSectionDriversLicensesSubtitle,
                    count: _entryCounts['DRIVERS_LICENSE'] ?? 0,
                    enabled: isLoggedIn && _limits.isFeatureEnabled('DRIVERS_LICENSE'),
                    loginRequired: !isLoggedIn,
                    onTap: _onTap(
                      isLoggedIn && _limits.isFeatureEnabled('DRIVERS_LICENSE'),
                      () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const IdentityDocumentPage(
                            documentType: IdentityDocumentType.driversLicense,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  _SectionTile(
                    icon: Icons.travel_explore_outlined,
                    title: localizations.dataSectionVisas,
                    subtitle: localizations.dataSectionVisasSubtitle,
                    count: _entryCounts['VISA'] ?? 0,
                    enabled: isLoggedIn && _limits.isFeatureEnabled('VISA'),
                    loginRequired: !isLoggedIn,
                    onTap: _onTap(
                      isLoggedIn && _limits.isFeatureEnabled('VISA'),
                      () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const VisaPage()),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  _SectionTile(
                    icon: Icons.confirmation_number_outlined,
                    title: localizations.dataSectionTickets,
                    subtitle: localizations.dataSectionTicketsSubtitle,
                    count: _entryCounts['TICKET'] ?? 0,
                    enabled: isLoggedIn && _limits.isFeatureEnabled('TICKET'),
                    loginRequired: !isLoggedIn,
                    onTap: _onTap(
                      isLoggedIn && _limits.isFeatureEnabled('TICKET'),
                      () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const TicketPage()),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  _SectionTile(
                    icon: Icons.receipt_long_outlined,
                    title: localizations.receiptTitle,
                    subtitle: localizations.receiptSubtitle,
                    count: _entryCounts['RECEIPT'] ?? 0,
                    enabled: isLoggedIn && _limits.receiptsEnabled,
                    loginRequired: !isLoggedIn,
                    onTap: _onTap(
                      isLoggedIn && _limits.receiptsEnabled,
                      () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const ReceiptPage()),
                      ),
                    ),
                  ),
                ]),
              ),
            ),
            _sectionHeader(localizations.dataSectionMediaHeader, theme),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  _SectionTile(
                    icon: Icons.photo_outlined,
                    title: localizations.imagesTitle,
                    subtitle: localizations.imagesSubtitle,
                    count: _entryCounts['IMAGE'] ?? 0,
                    enabled: isLoggedIn && _limits.isFeatureEnabled('IMAGE'),
                    loginRequired: !isLoggedIn,
                    onTap: _onTap(
                      isLoggedIn && _limits.isFeatureEnabled('IMAGE'),
                      () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const ImagePage()),
                      ),
                    ),
                  ),
                ]),
              ),
            ),
            const SliverPadding(padding: EdgeInsets.only(bottom: 24)),
          ],
        ),
      ),
    );
  }

  SliverPadding _sectionHeader(String text, ThemeData theme) {
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      sliver: SliverToBoxAdapter(
        child: Text(
          text,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
            letterSpacing: 0.8,
          ),
        ),
      ),
    );
  }
}

class _SectionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final int count;
  final bool enabled;
  final bool loginRequired;
  final VoidCallback? onTap;

  const _SectionTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.count,
    required this.enabled,
    required this.onTap,
    this.loginRequired = false,
  });

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final opacity = enabled ? 1.0 : 0.38;

    return Opacity(
      opacity: opacity,
      child: Card(
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 0,
        color: theme.colorScheme.surface,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: theme.colorScheme.primary, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(title, style: theme.textTheme.titleSmall),
                          if (!enabled && !loginRequired) ...[
                            const SizedBox(width: 8),
                            const TierBadge('Pro'),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        loginRequired ? localizations.loginRequiredForFeature : subtitle,
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                if (enabled)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (count > 0)
                        Text(
                          localizations.recordCount(count),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      const SizedBox(height: 2),
                      Icon(
                        Icons.chevron_right,
                        size: 18,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
                      ),
                    ],
                  )
                else
                  Icon(
                    loginRequired ? Icons.person_outline : Icons.lock_outline,
                    size: 18,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
