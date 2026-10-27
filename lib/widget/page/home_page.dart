// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Patrick Zwick

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../messages/app_localizations.dart';
import '../../service/services.dart';
import '../../util/scaffold_messenger_key.dart';
import '../../util/storage.dart';
import '../sheet/paywall_sheet.dart';
import 'dashboard_page.dart';
import 'data_page.dart';
import 'memories_page.dart';
import 'settings_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;
  int _dashboardRefreshTrigger = 0;
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    Future.delayed(const Duration(minutes: 2), _maybePushPrompt);
    Future.delayed(const Duration(seconds: 30), _maybeShowTrialPopup);
    _checkDeletionCancelledNotification();
  }

  void _maybePushPrompt() {
    if (mounted) {
      pushNotificationService.maybePrompt(context);
    }
  }

  Future<void> _maybeShowTrialPopup() async {
    if (!mounted) {
      return;
    }

    final limits = await limitsService.getCachedLimits();

    if (!mounted) {
      return;
    }

    if (!limits.isFree) {
      return;
    }

    const maxTrialPopups = 3;

    final countRaw = await storage.read(key: 'trial_popup_count');
    final count = int.tryParse(countRaw ?? '0') ?? 0;

    if (count >= maxTrialPopups) {
      return;
    }

    final nextShowRaw = await storage.read(key: 'trial_popup_next_show');
    final now = DateTime.now().millisecondsSinceEpoch;

    if (nextShowRaw != null) {
      final nextShow = int.tryParse(nextShowRaw) ?? 0;

      if (now < nextShow) {
        return;
      }
    }

    await storage.write(key: 'trial_popup_count', value: (count + 1).toString());
    final nextShowTime = now + const Duration(days: 7).inMilliseconds;
    await storage.write(key: 'trial_popup_next_show', value: nextShowTime.toString());

    if (!mounted) {
      return;
    }

    final localizations = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => _TrialPopup(
        localizations: localizations,
        theme: theme,
        onStartTrial: () {
          Navigator.of(sheetContext).pop();
          showPaywall(context);
        },
      ),
    );
  }

  Future<void> _checkDeletionCancelledNotification() async {
    final flag = await storage.read(key: 'deletion_cancelled_notification');

    if (flag != 'true' || !mounted) {
      return;
    }

    await storage.delete(key: 'deletion_cancelled_notification');

    if (!mounted) {
      return;
    }

    final localizations = AppLocalizations.of(context)!;

    scaffoldMessengerKey.currentState?.showSnackBar(
      SnackBar(content: Text(localizations.accountDeletionCancelled, textAlign: TextAlign.center)),
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _switchToTab(int index) {
    if (index == 0 && _selectedIndex != 0) {
      _dashboardRefreshTrigger++;
    }

    setState(() => _selectedIndex = index);

    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Scaffold(
      body: PageView(
        controller: _pageController,
        onPageChanged: (index) {
          if (index == 0 && _selectedIndex != 0) {
            _dashboardRefreshTrigger++;
          }

          setState(() => _selectedIndex = index);
        },
        children: [
          DashboardPage(refreshTrigger: _dashboardRefreshTrigger),
          const MemoriesPage(),
          const DataPage(),
          const SettingsPage(),
        ],
      ),
      bottomNavigationBar: DecoratedBox(
        decoration: BoxDecoration(
          color: Color.lerp(
            theme.colorScheme.surface,
            theme.colorScheme.onSurface,
            0.04,
          ),
          border: Border(
            top: BorderSide(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.08),
              width: 0.5,
            ),
          ),
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 56,
            child: Row(
              children: [
                _NavItem(
                  key: const ValueKey('tab_home'),
                  icon: Icons.home_outlined,
                  label: localizations.tabHome,
                  selected: _selectedIndex == 0,
                  onTap: () => _switchToTab(0),
                ),
                _NavItem(
                  key: const ValueKey('tab_memories'),
                  icon: Icons.photo_album_outlined,
                  label: localizations.tabMemories,
                  selected: _selectedIndex == 1,
                  onTap: () => _switchToTab(1),
                ),
                _NavItem(
                  key: const ValueKey('tab_data'),
                  icon: Icons.show_chart,
                  label: localizations.tabData,
                  selected: _selectedIndex == 2,
                  onTap: () => _switchToTab(2),
                ),
                _NavItem(
                  icon: Icons.settings_outlined,
                  label: localizations.tabSettings,
                  selected: _selectedIndex == 3,
                  onTap: () => _switchToTab(3),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _NavItem({
    super.key,
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final targetColor = selected
        ? theme.colorScheme.primary
        : theme.colorScheme.onSurface.withValues(alpha: 0.4);

    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: TweenAnimationBuilder<Color?>(
          tween: ColorTween(end: targetColor),
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          builder: (context, color, _) {
            return Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedScale(
                  scale: selected ? 1.0 : 0.85,
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOutCubic,
                  child: Icon(icon, color: color, size: 22),
                ),
                const SizedBox(height: 3),
                Text(
                  label,
                  style: theme.textTheme.labelSmall!.copyWith(
                    color: color,
                    fontWeight: selected ? FontWeight.w500 : FontWeight.normal,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _TrialPopup extends StatelessWidget {
  final AppLocalizations localizations;
  final ThemeData theme;
  final VoidCallback onStartTrial;

  const _TrialPopup({
    required this.localizations,
    required this.theme,
    required this.onStartTrial,
  });

  @override
  Widget build(BuildContext context) {
    final primary = theme.colorScheme.primary;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(Icons.workspace_premium_outlined, color: primary, size: 26),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              localizations.trialPopupTitle,
              style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              localizations.trialPopupBody,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: onStartTrial,
              child: Text(localizations.trialPopupCta),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              style: TextButton.styleFrom(
                foregroundColor: theme.colorScheme.onSurface.withValues(alpha: 0.45),
              ),
              child: Text(localizations.trialPopupDismiss),
            ),
            const SizedBox(height: 4),
            GestureDetector(
              onTap: () => launchUrl(
                Uri.parse('$baseUrl#pricing'),
                mode: LaunchMode.externalApplication,
              ),
              child: Text(
                localizations.subscriptionPricingPage,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: primary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

