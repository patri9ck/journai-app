// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Patrick Zwick

import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../messages/app_localizations.dart';
import '../../model/limits.dart';
import '../../model/result.dart';
import '../../model/user_info.dart';
import '../../service/services.dart';
import '../../util/auth_notifier.dart';
import '../../util/auth_scope.dart';
import '../../util/scaffold_messenger_key.dart';
import '../../util/storage.dart';
import '../../util/notifications_notifier.dart';
import '../../util/units_notifier.dart';
import '../shared/email_address_text_field.dart';
import '../shared/phone_number_text_field.dart';
import '../shared/verification_code_text_field.dart';
import '../sheet/encryption_sheet.dart';
import '../sheet/paywall_sheet.dart';
import 'start_page.dart';
import 'travel_warning_alert_page.dart';
import '../shared/loading_button.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _notificationsEnabled = false;
  bool _newsNotificationsEnabled = false;
  bool _metricUnits = true;
  bool? _healthScanConsent;
  bool? _documentScanConsent;
  bool _loadingConsents = true;
  UserInfo? _userInfo;
  bool _loadingUserInfo = true;
  bool? _encryptionSetup;
  String _version = '';
  Limits? _limits;

  @override
  void initState() {
    super.initState();
    newsNotificationsNotifier.addListener(_onNewsNotificationsChanged);
    _loadPreferences();
  }

  @override
  void dispose() {
    newsNotificationsNotifier.removeListener(_onNewsNotificationsChanged);
    super.dispose();
  }

  void _onNewsNotificationsChanged() {
    if (mounted) {
      setState(() => _newsNotificationsEnabled = newsNotificationsNotifier.value);
    }
  }

  static const _cacheKeyUserEmail = 'cache_user_info_email';
  static const _cacheKeyUserPhone = 'cache_user_info_phone';
  static const _cacheKeyUserGoogleLinked = 'cache_user_info_googleLinked';
  static const _cacheKeyUserAppleLinked = 'cache_user_info_appleLinked';
  static const _cacheKeyConsentHealth = 'cache_consent_health';
  static const _cacheKeyConsentDocument = 'cache_consent_document';

  Future<void> _loadPreferences() async {
    final (
      notifications,
      newsNotifications,
      units,
      cachedUserInfo,
      cachedHealthConsent,
      cachedDocumentConsent,
      cachedLimits,
    ) = await (
      storage.read(key: 'settings_notifications_enabled'),
      pushNotificationService.isEnabled(),
      storage.read(key: 'settings_units_metric'),
      _readCachedUserInfo(),
      storage.read(key: _cacheKeyConsentHealth),
      storage.read(key: _cacheKeyConsentDocument),
      limitsService.getCachedLimits(),
    ).wait;

    PackageInfo packageInfo;

    try {
      packageInfo = await PackageInfo.fromPlatform();
    } catch (_) {
      packageInfo = PackageInfo(
        appName: 'Journai',
        packageName: 'xyz.journai.app',
        version: '1.0.0',
        buildNumber: '1',
      );
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _notificationsEnabled = notifications == 'true';
      _newsNotificationsEnabled = newsNotifications;
      _metricUnits = units != 'false';
      _version = '${packageInfo.version} (${packageInfo.buildNumber})';
      _limits = cachedLimits;

      if (cachedUserInfo != null) {
        _userInfo = cachedUserInfo;
        _loadingUserInfo = false;
      }

      if (cachedHealthConsent != null && cachedDocumentConsent != null) {
        _healthScanConsent = cachedHealthConsent == 'true';
        _documentScanConsent = cachedDocumentConsent == 'true';
        _loadingConsents = false;
      }
    });

    await Future.wait([_loadConsents(), _loadUserInfo(), _loadEncryptionSetup(), _loadLimits()]);
  }

  Future<UserInfo?> _readCachedUserInfo() async {
    final (googleLinked, emailRaw, phoneRaw, appleLinked) = await (
      storage.read(key: _cacheKeyUserGoogleLinked),
      storage.read(key: _cacheKeyUserEmail),
      storage.read(key: _cacheKeyUserPhone),
      storage.read(key: _cacheKeyUserAppleLinked),
    ).wait;

    if (googleLinked == null) {
      return null;
    }

    return UserInfo(
      email: (emailRaw == null || emailRaw.isEmpty) ? null : emailRaw,
      phone: (phoneRaw == null || phoneRaw.isEmpty) ? null : phoneRaw,
      googleLinked: googleLinked == 'true',
      appleLinked: appleLinked == 'true',
    );
  }

  Future<void> _writeCachedUserInfo(UserInfo info) async {
    await Future.wait([
      storage.write(key: _cacheKeyUserEmail, value: info.email ?? ''),
      storage.write(key: _cacheKeyUserPhone, value: info.phone ?? ''),
      storage.write(key: _cacheKeyUserGoogleLinked, value: info.googleLinked.toString()),
      storage.write(key: _cacheKeyUserAppleLinked, value: info.appleLinked.toString()),
    ]);
  }

  Future<void> _loadLimits() async {
    if (!AuthScope.of(context)) {
      return;
    }

    final limits = await limitsService.getLimits();

    if (!mounted) {
      return;
    }

    setState(() => _limits = limits);
  }

  Future<void> _loadEncryptionSetup() async {
    if (!AuthScope.of(context)) {
      return;
    }

    final setup = await encryptionService.hasEncryptionSetup();

    if (!mounted) {
      return;
    }

    setState(() => _encryptionSetup = setup);
  }

  Future<void> _loadConsents() async {
    if (!AuthScope.of(context)) {
      if (mounted) {
        setState(() => _loadingConsents = false);
      }
      return;
    }

    final healthConsent = await consentService.hasHealthDataScanConsent();
    final documentConsent = await consentService.hasDocumentScanConsent();

    if (!mounted) {
      return;
    }

    await Future.wait([
      storage.write(key: _cacheKeyConsentHealth, value: healthConsent.toString()),
      storage.write(key: _cacheKeyConsentDocument, value: documentConsent.toString()),
    ]);

    setState(() {
      _healthScanConsent = healthConsent;
      _documentScanConsent = documentConsent;
      _loadingConsents = false;
    });
  }

  Future<void> _loadUserInfo() async {
    if (!AuthScope.of(context)) {
      if (mounted) {
        setState(() => _loadingUserInfo = false);
      }
      return;
    }

    final result = await requestService.getAuthenticatedRequest('user/me');

    if (!mounted) {
      return;
    }

    if (result is Success<Map<String, dynamic>>) {
      final userInfo = UserInfo.fromJson(result.value!);

      await _writeCachedUserInfo(userInfo);

      setState(() {
        _userInfo = userInfo;
        _loadingUserInfo = false;
      });
    } else {
      setState(() => _loadingUserInfo = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final isLoggedIn = AuthScope.of(context);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            title: Text(localizations.settingsTitle),
            backgroundColor: theme.colorScheme.surface,
            surfaceTintColor: Colors.transparent,
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _SectionLabel(localizations.settingsSectionUnits),
                _SettingsCard(children: [
                  _UnitsTile(
                    localizations: localizations,
                    isMetric: _metricUnits,
                    onChanged: (isMetric) async {
                      setState(() => _metricUnits = isMetric);
                      metricUnitsNotifier.value = isMetric;
                      await storage.write(
                        key: 'settings_units_metric',
                        value: isMetric ? 'true' : 'false',
                      );
                    },
                  ),
                ]),
                if (isLoggedIn) ...[
                  _SectionLabel(localizations.settingsSectionSubscription),
                  _SubscriptionCard(
                    localizations: localizations,
                    theme: theme,
                    limits: _limits,
                    onManage: () => _openPaywall(context),
                  ),
                ],
                _SectionLabel(localizations.settingsSectionNotifications),
                _SettingsCard(children: [
                  _SwitchTile(
                    icon: Icons.notifications_outlined,
                    iconColor: Colors.orange,
                    label: localizations.settingsExpiryReminders,
                    hint: localizations.settingsExpiryRemindersHint,
                    value: _notificationsEnabled,
                    onChanged: (enabled) => _toggleNotifications(context, localizations, enabled),
                  ),
                  _SwitchTile(
                    icon: Icons.campaign_outlined,
                    iconColor: Colors.orange,
                    label: localizations.settingsNewsNotifications,
                    hint: localizations.settingsNewsNotificationsHint,
                    value: _newsNotificationsEnabled,
                    onChanged: (enabled) => _toggleNewsNotifications(context, localizations, enabled),
                  ),
                  if (isLoggedIn) ...[
                    const _CardDivider(),
                    _TileRow(
                      icon: Icons.warning_amber_outlined,
                      iconColor: Colors.orange,
                      label: localizations.travelWarningAlertsTitle,
                      value: _limits?.travelWarningAlertsEnabled == true ? null : localizations.travelWarningAlertsLocked,
                      onTap: () => _openTravelWarningAlerts(context),
                    ),
                  ],
                ]),
                if (!isLoggedIn) ...[
                  _SectionLabel(localizations.settingsSectionAccount),
                  _SettingsCard(children: [
                    _TileRow(
                      icon: Icons.login,
                      iconColor: theme.colorScheme.primary,
                      label: localizations.settingsSignIn,
                      labelColor: theme.colorScheme.primary,
                      onTap: () => Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(builder: (_) => const StartPage()),
                        (_) => false,
                      ),
                    ),
                  ]),
                ],
                if (isLoggedIn) ...[
                  _SectionLabel(localizations.settingsSectionAccount),
                  _SettingsCard(children: [
                    _LoginMethodTile(
                      icon: Icons.email_outlined,
                      iconColor: Colors.indigo,
                      label: localizations.settingsLoginMethodEmail,
                      value: _userInfo?.email,
                      isLoading: _loadingUserInfo,
                      canRemove: (_userInfo?.loginMethodCount ?? 0) > 1,
                      removeLabel: localizations.removeEmail,
                      onTap: () => _showChangeContact(
                        context,
                        localizations,
                        theme,
                        isEmail: true,
                      ),
                      onRemove: () => _removeContact(context, localizations, isEmail: true),
                    ),
                    const _CardDivider(),
                    _LoginMethodTile(
                      icon: Icons.phone_outlined,
                      iconColor: Colors.teal,
                      label: localizations.settingsLoginMethodPhone,
                      value: _userInfo?.phone,
                      isLoading: _loadingUserInfo,
                      canRemove: (_userInfo?.loginMethodCount ?? 0) > 1,
                      removeLabel: localizations.removePhone,
                      onTap: () => _showChangeContact(
                        context,
                        localizations,
                        theme,
                        isEmail: false,
                      ),
                      onRemove: () => _removeContact(context, localizations, isEmail: false),
                    ),
                    if (_userInfo?.googleLinked == true) ...[
                      const _CardDivider(),
                      _TileRow(
                        icon: Icons.g_mobiledata,
                        iconColor: Colors.red,
                        label: localizations.settingsLoginMethodGoogle,
                        value: localizations.settingsLoginMethodLinked,
                      ),
                    ],
                    if (_userInfo?.appleLinked == true && Platform.isIOS) ...[
                      const _CardDivider(),
                      _TileRow(
                        icon: Icons.apple,
                        iconColor: Colors.black,
                        label: localizations.settingsLoginMethodApple,
                        value: localizations.settingsLoginMethodLinked,
                      ),
                    ],
                    const _CardDivider(),
                    _TileRow(
                      icon: Icons.logout,
                      iconColor: theme.colorScheme.error,
                      label: localizations.settingsSignOut,
                      labelColor: theme.colorScheme.error,
                      onTap: () => _confirmSignOut(context, localizations),
                    ),
                    const _CardDivider(),
                    _TileRow(
                      icon: Icons.devices_outlined,
                      iconColor: theme.colorScheme.error,
                      label: localizations.settingsSignOutAll,
                      labelColor: theme.colorScheme.error,
                      onTap: () => _confirmSignOutAll(context, localizations),
                    ),
                    const _CardDivider(),
                    _TileRow(
                      icon: Icons.delete_forever_outlined,
                      iconColor: theme.colorScheme.error,
                      label: localizations.settingsDeleteAccount,
                      labelColor: theme.colorScheme.error,
                      onTap: () => _confirmDeleteAccount(context, localizations),
                    ),
                  ]),
                  _SectionLabel(localizations.settingsSectionEncryption),
                  _SettingsCard(children: [
                    _TileRow(
                      icon: Icons.lock_outline,
                      iconColor: Colors.purple,
                      label: localizations.settingsChangePassword,
                      enabled: _encryptionSetup == true,
                      onTap: () => _showChangePassword(context, localizations, theme),
                    ),
                    const _CardDivider(),
                    _TileRow(
                      icon: Icons.delete_outline,
                      iconColor: theme.colorScheme.error,
                      label: localizations.settingsResetEncryption,
                      labelColor: theme.colorScheme.error,
                      onTap: () => _confirmReset(context, localizations),
                    ),
                  ]),
                  _SectionLabel(localizations.settingsSectionPrivacy),
                  _SettingsCard(children: [
                    _ConsentTile(
                      icon: Icons.health_and_safety_outlined,
                      iconColor: Colors.green,
                      label: localizations.settingsConsentHealthScan,
                      granted: _healthScanConsent,
                      loading: _loadingConsents,
                      localizations: localizations,
                      onRevoke: () => _revokeConsent(context, localizations, isHealthScan: true),
                    ),
                    const _CardDivider(),
                    _ConsentTile(
                      icon: Icons.badge_outlined,
                      iconColor: Colors.blueGrey,
                      label: localizations.settingsConsentDocumentScan,
                      granted: _documentScanConsent,
                      loading: _loadingConsents,
                      localizations: localizations,
                      onRevoke: () => _revokeConsent(context, localizations, isHealthScan: false),
                    ),
                  ]),
                ],
              ]),
            ),
          ),
          SliverFillRemaining(
            hasScrollBody: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Center(
                    child: Image.asset('assets/icon.png', width: 36, height: 36),
                  ),
                  const SizedBox(height: 8),
                  Center(
                    child: Text(
                      localizations.settingsVersion(_version),
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Center(
                    child: RichText(
                      textAlign: TextAlign.center,
                      text: TextSpan(
                        style: theme.textTheme.bodySmall,
                        children: [
                          TextSpan(text: '${localizations.loginCaption} '),
                          TextSpan(
                            text: '${localizations.help}?',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.primary,
                            ),
                            recognizer: TapGestureRecognizer()
                              ..onTap = () {
                                launchUrl(
                                  Uri.parse('${baseUrl}support/'),
                                  mode: LaunchMode.externalApplication,
                                );
                              },
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Center(
                    child: RichText(
                      textAlign: TextAlign.center,
                      text: TextSpan(
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.45),
                        ),
                        children: [
                          TextSpan(
                            text: localizations.legalNotice,
                            style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.55)),
                            recognizer: TapGestureRecognizer()
                              ..onTap = () => launchUrl(
                                    Uri.parse('${baseUrl}legal-notice/'),
                                    mode: LaunchMode.externalApplication,
                                  ),
                          ),
                          const TextSpan(text: ' - '),
                          TextSpan(
                            text: localizations.termsOfService,
                            style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.55)),
                            recognizer: TapGestureRecognizer()
                              ..onTap = () => launchUrl(
                                    Uri.parse('${baseUrl}terms-of-service/'),
                                    mode: LaunchMode.externalApplication,
                                  ),
                          ),
                          const TextSpan(text: ' - '),
                          TextSpan(
                            text: localizations.privacyPolicy,
                            style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.55)),
                            recognizer: TapGestureRecognizer()
                              ..onTap = () => launchUrl(
                                    Uri.parse('${baseUrl}privacy-policy/'),
                                    mode: LaunchMode.externalApplication,
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openPaywall(BuildContext context) async {
    final purchased = await showPaywall(context, currentTier: _limits?.tier ?? 'FREE');

    if (purchased == true) {
      await _loadLimits();
    }
  }

  Future<void> _openTravelWarningAlerts(BuildContext context) async {
    if (_limits?.travelWarningAlertsEnabled != true) {
      await _openPaywall(context);

      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const TravelWarningAlertPage()),
    );
  }

  Future<void> _toggleNotifications(
    BuildContext context,
    AppLocalizations localizations,
    bool enabled,
  ) async {
    if (enabled) {
      final granted = await notificationService.requestPermission();

      if (!mounted) {
        return;
      }

      if (!granted) {
        if (!context.mounted) {
          return;
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(localizations.settingsNotificationPermissionDenied, textAlign: TextAlign.center),
          ),
        );
        return;
      }
    }

    setState(() => _notificationsEnabled = enabled);
    await notificationService.setEnabled(enabled);

    if (!enabled) {
      await notificationService.scheduleNotifications([]);
    }
  }

  Future<void> _toggleNewsNotifications(
    BuildContext context,
    AppLocalizations localizations,
    bool enabled,
  ) async {
    if (enabled) {
      final status = await pushNotificationService.enable();

      if (!mounted) {
        return;
      }

      if (status != AuthorizationStatus.authorized) {
        if (!context.mounted) {
          return;
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(localizations.settingsNotificationPermissionDenied, textAlign: TextAlign.center),
          ),
        );

        return;
      }
    } else {
      await pushNotificationService.disable();
    }

    if (!mounted) {
      return;
    }

    setState(() => _newsNotificationsEnabled = enabled);
  }

  Future<void> _confirmSignOut(BuildContext context, AppLocalizations localizations) => _signOut(
    context,
    title: localizations.settingsSignOutConfirm,
    body: localizations.settingsSignOutConfirmBody,
    confirmLabel: localizations.settingsSignOutConfirmYes,
    path: 'logout',
  );

  Future<void> _confirmSignOutAll(BuildContext context, AppLocalizations localizations) => _signOut(
    context,
    title: localizations.settingsSignOutAllConfirm,
    body: localizations.settingsSignOutAllConfirmBody,
    confirmLabel: localizations.settingsSignOutAllConfirmYes,
    path: 'logout/all',
    requireSuccess: true,
  );

  Future<void> _confirmDeleteAccount(BuildContext context, AppLocalizations localizations) => _signOut(
    context,
    title: localizations.settingsDeleteAccountConfirm,
    body: localizations.settingsDeleteAccountConfirmBody,
    confirmLabel: localizations.settingsDeleteAccountConfirmYes,
    path: 'logout/all',
    requestBody: {'deleteAccount': true},
    requireSuccess: true,
    successMessage: localizations.settingsDeleteAccountScheduled,
  );

  Future<void> _signOut(
    BuildContext context, {
    required String title,
    required String body,
    required String confirmLabel,
    required String path,
    Map<String, dynamic> requestBody = const {},
    bool requireSuccess = false,
    String? successMessage,
  }) async {
    final localizations = AppLocalizations.of(context)!;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(localizations.back),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(confirmLabel, style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) {
      return;
    }

    final result = await requestService.postAuthenticatedRequest(path, requestBody);

    if (requireSuccess && result is Failure) {
      (result as Failure).show(localizations);

      return;
    }

    await clearAccount();

    isLoggedInNotifier.value = false;

    if (!context.mounted) {
      return;
    }

    if (successMessage != null) {
      scaffoldMessengerKey.currentState?.showSnackBar(
        SnackBar(content: Text(successMessage, textAlign: TextAlign.center)),
      );
    }

    Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const StartPage()),
      (_) => false,
    );
  }

  void _showChangeContact(
    BuildContext context,
    AppLocalizations localizations,
    ThemeData theme, {
    required bool isEmail,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _UpdateContactSheet(isEmail: isEmail, localizations: localizations, theme: theme),
    ).then((_) => _loadUserInfo());
  }

  Future<void> _removeContact(
    BuildContext context,
    AppLocalizations localizations, {
    required bool isEmail,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(localizations.settingsRemoveConfirm),
        content: Text(localizations.settingsRemoveConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(localizations.back),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(
              localizations.settingsRemoveConfirmYes,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) {
      return;
    }

    final result = await requestService.deleteAuthenticatedRequest(
      isEmail ? 'user/email' : 'user/phone',
    );

    if (!context.mounted) {
      return;
    }

    if (result is Failure) {
      (result as Failure).show(localizations);
      return;
    }

    await _loadUserInfo();
  }

  Future<void> _showChangePassword(
    BuildContext context,
    AppLocalizations localizations,
    ThemeData theme,
  ) async {
    final unlocked = await ensureEncryptionUnlocked(context);

    if (!unlocked || !context.mounted) {
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _ChangePasswordSheet(localizations: localizations, theme: theme),
    );
  }

  Future<void> _confirmReset(
    BuildContext context,
    AppLocalizations localizations,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(localizations.settingsResetEncryption),
        content: Text(localizations.settingsResetEncryptionBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(localizations.back),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(
              localizations.settingsResetEncryptionConfirm,
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) {
      return;
    }

    final deleteDataResult = await dataService.deleteAllData();

    if (deleteDataResult is Failure<void>) {
      deleteDataResult.show(localizations);

      return;
    }

    final deleteEncryptionResult = voidResult(await requestService.deleteAuthenticatedRequest('user/encryption'));

    if (deleteEncryptionResult is Failure<void>) {
      deleteEncryptionResult.show(localizations);

      return;
    }

    await storage.delete(key: 'dataKey');
    await storage.delete(key: 'encryptedDataKey');

    if (!context.mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(localizations.changeSuccess, textAlign: TextAlign.center)),
    );
  }

  Future<void> _revokeConsent(
    BuildContext context,
    AppLocalizations localizations, {
    required bool isHealthScan,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(localizations.settingsConsentRevokeConfirmTitle),
        content: Text(localizations.settingsConsentRevokeConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(localizations.back),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(
              localizations.settingsConsentRevokeConfirmYes,
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) {
      return;
    }

    final result = isHealthScan
        ? await consentService.revokeHealthDataScanConsent()
        : await consentService.revokeDocumentScanConsent();

    if (!context.mounted) {
      return;
    }

    if (result is Failure) {
      result.show(localizations);
      return;
    }

    setState(() {
      if (isHealthScan) {
        _healthScanConsent = false;
      } else {
        _documentScanConsent = false;
      }
    });

    final newHealth = _healthScanConsent ?? false;
    final newDocument = _documentScanConsent ?? false;

    await Future.wait([
      storage.write(key: _cacheKeyConsentHealth, value: newHealth.toString()),
      storage.write(key: _cacheKeyConsentDocument, value: newDocument.toString()),
    ]);
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;

  const _SectionLabel(this.label);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(left: 4, top: 20, bottom: 6),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.45),
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  final List<Widget> children;

  const _SettingsCard({required this.children});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: Color.lerp(
          theme.colorScheme.surface,
          theme.colorScheme.onSurface,
          0.04,
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(children: children),
    );
  }
}

class _CardDivider extends StatelessWidget {
  const _CardDivider();

  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      indent: 52,
      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.07),
    );
  }
}

class _TileRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String? value;
  final Color? labelColor;
  final VoidCallback? onTap;
  final bool enabled;

  const _TileRow({
    required this.icon,
    required this.iconColor,
    required this.label,
    this.value,
    this.labelColor,
    this.onTap,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Opacity(
      opacity: enabled ? 1.0 : 0.4,
      child: InkWell(
        onTap: enabled ? onTap : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          child: Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 16, color: iconColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: theme.textTheme.bodyMedium?.copyWith(color: labelColor),
                ),
              ),
              if (value != null) ...[
                Text(
                  value!,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.45),
                  ),
                ),
                const SizedBox(width: 4),
              ],
              if (onTap != null && labelColor == null && enabled)
                Icon(
                  Icons.chevron_right,
                  size: 16,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.25),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SwitchTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String? hint;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SwitchTile({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    required this.onChanged,
    this.hint,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 11, 14, 11),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: iconColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: theme.textTheme.bodyMedium),
                if (hint != null) ...[
                  const SizedBox(height: 2),
                  Text(hint!, style: theme.textTheme.bodySmall),
                ],
              ],
            ),
          ),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

class _UnitsTile extends StatelessWidget {
  final AppLocalizations localizations;
  final bool isMetric;
  final ValueChanged<bool> onChanged;

  const _UnitsTile({
    required this.localizations,
    required this.isMetric,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: Colors.cyan.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.straighten_outlined, size: 16, color: Colors.cyan),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: SegmentedButton<bool>(
              segments: [
                ButtonSegment<bool>(
                  value: true,
                  label: Text(localizations.settingsUnitsMetric),
                ),
                ButtonSegment<bool>(
                  value: false,
                  label: Text(localizations.settingsUnitsImperial),
                ),
              ],
              selected: {isMetric},
              onSelectionChanged: (selection) => onChanged(selection.first),
              style: ButtonStyle(
                visualDensity: VisualDensity.compact,
                textStyle: WidgetStateProperty.all(theme.textTheme.labelSmall),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ConsentTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final bool? granted;
  final bool loading;
  final AppLocalizations localizations;
  final VoidCallback onRevoke;

  const _ConsentTile({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.granted,
    required this.loading,
    required this.localizations,
    required this.onRevoke,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: iconColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: theme.textTheme.bodyMedium),
                const SizedBox(height: 2),
                if (loading)
                  Text('...', style: theme.textTheme.bodySmall)
                else
                  Text(
                    granted == true
                        ? localizations.settingsConsentGranted
                        : localizations.settingsConsentNotGranted,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: granted == true
                          ? Colors.green.shade600
                          : theme.colorScheme.onSurface.withValues(alpha: 0.4),
                    ),
                  ),
              ],
            ),
          ),
          if (granted == true)
            TextButton(
              onPressed: onRevoke,
              style: TextButton.styleFrom(
                foregroundColor: theme.colorScheme.error,
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
              ),
              child: Text(localizations.settingsConsentRevoke),
            ),
        ],
      ),
    );
  }
}

class _LoginMethodTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String? value;
  final bool isLoading;
  final bool canRemove;
  final String removeLabel;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  const _LoginMethodTile({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    required this.isLoading,
    required this.canRemove,
    required this.removeLabel,
    required this.onTap,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final localizations = AppLocalizations.of(context)!;
    final isLinked = value != null;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Row(
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 16, color: iconColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: theme.textTheme.bodyMedium),
                  const SizedBox(height: 2),
                  if (isLoading)
                    Text('...', style: theme.textTheme.bodySmall)
                  else if (isLinked)
                    Text(
                      value!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                      ),
                      overflow: TextOverflow.ellipsis,
                    )
                  else
                    Text(
                      localizations.settingsLoginMethodNotLinked,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
                      ),
                    ),
                ],
              ),
            ),
            if (!isLoading && isLinked && canRemove) ...[
              TextButton(
                onPressed: onRemove,
                style: TextButton.styleFrom(
                  foregroundColor: theme.colorScheme.error,
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                ),
                child: Text(
                  removeLabel,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
              ),
            ] else if (!isLoading) ...[
              Icon(
                Icons.chevron_right,
                size: 16,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.25),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _UpdateContactSheet extends StatefulWidget {
  final bool isEmail;
  final AppLocalizations localizations;
  final ThemeData theme;

  const _UpdateContactSheet({required this.isEmail, required this.localizations, required this.theme});

  @override
  State<_UpdateContactSheet> createState() => _UpdateContactSheetState();
}

class _UpdateContactSheetState extends State<_UpdateContactSheet> {
  String? _validContact;
  bool _submitted = false;
  bool _loading = false;
  bool _codeSent = false;
  String? _error;
  final _codeController = TextEditingController();

  String get _type => widget.isEmail ? 'email' : 'phone';

  String get _contactKey => widget.isEmail ? 'emailAddress' : 'phoneNumber';

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final localizations = widget.localizations;
    final theme = widget.theme;

    final error = _error == null
        ? null
        : Padding(
            padding: const EdgeInsets.only(left: 12, top: 6),
            child: Text(_error!, style: TextStyle(fontSize: 12, color: theme.colorScheme.error)),
          );

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(left: 24, right: 24, top: 24, bottom: MediaQuery.of(context).viewInsets.bottom + 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.isEmail ? localizations.changeEmailTitle : localizations.changePhoneTitle,
              style: theme.textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),
            if (!_codeSent) ...[
              if (widget.isEmail)
                EmailAddressTextField(onSubmit: (email) => _validContact = email, submitted: _submitted)
              else
                PhoneNumberTextField(onSubmit: (phone) => _validContact = phone, submitted: _submitted),
              ?error,
              const SizedBox(height: 16),
              LoadingButton(
                loading: _loading,
                onPressed: _requestCode,
                label: widget.isEmail ? localizations.requestEmail : localizations.requestSms,
              ),
            ] else ...[
              Text(localizations.enterCodeFromInbox, style: theme.textTheme.bodySmall),
              const SizedBox(height: 16),
              VerificationCodeTextField(controller: _codeController, onSubmitted: _verifyCode),
              ?error,
              const SizedBox(height: 16),
              LoadingButton(loading: _loading, onPressed: _verifyCode, label: localizations.verify),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _requestCode() async {
    setState(() {
      _submitted = true;
      _error = null;
    });

    final contact = _validContact;

    if (contact == null) {
      return;
    }

    setState(() => _loading = true);

    final result = await requestService.postAuthenticatedRequest('update/$_type', {_contactKey: contact});

    if (!mounted) {
      return;
    }

    final isPending = result is ServerFailure && (result as ServerFailure).key == 'pending-verification';

    setState(() {
      _loading = false;
      _codeSent = result is! Failure || isPending;
      _error = result is Failure ? (result as Failure).localizedMessage(widget.localizations) : null;
    });
  }

  Future<void> _verifyCode() async {
    final code = _codeController.text.trim();
    final contact = _validContact;

    if (code.isEmpty || contact == null) {
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    final result = await requestService.postAuthenticatedRequest('update/verify/$_type', {
      _contactKey: contact,
      'code': code,
    });

    if (!mounted) {
      return;
    }

    if (result is Failure) {
      setState(() {
        _loading = false;
        _error = (result as Failure).localizedMessage(widget.localizations);
      });

      return;
    }

    Navigator.of(context).pop();

    scaffoldMessengerKey.currentState?.showSnackBar(
      SnackBar(content: Text(widget.localizations.changeSuccess, textAlign: TextAlign.center)),
    );
  }
}

class _SubscriptionCard extends StatelessWidget {
  final AppLocalizations localizations;
  final ThemeData theme;
  final Limits? limits;
  final VoidCallback onManage;

  const _SubscriptionCard({
    required this.localizations,
    required this.theme,
    required this.limits,
    required this.onManage,
  });

  String get _tierLabel {
    final tier = limits?.tier ?? 'FREE';

    if (tier == 'PRO') {
      return localizations.settingsSubscriptionTierPro;
    }

    if (tier == 'FAMILY') {
      return localizations.settingsSubscriptionTierFamily;
    }

    return localizations.settingsSubscriptionTierFree;
  }

  bool get _isPaid => !(limits?.isFree ?? true);

  @override
  Widget build(BuildContext context) {
    final primary = theme.colorScheme.primary;

    return Container(
      decoration: BoxDecoration(
        color: Color.lerp(theme.colorScheme.surface, theme.colorScheme.onSurface, 0.04),
        borderRadius: BorderRadius.circular(14),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onManage,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          child: Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.workspace_premium_outlined, size: 16, color: primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _tierLabel,
                      style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      _isPaid
                          ? localizations.settingsSubscriptionManage
                          : localizations.settingsSubscriptionUpgrade,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: _isPaid
                            ? theme.colorScheme.onSurface.withValues(alpha: 0.45)
                            : primary,
                        fontWeight: _isPaid ? null : FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                size: 16,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.25),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChangePasswordSheet extends StatefulWidget {
  final AppLocalizations localizations;
  final ThemeData theme;

  const _ChangePasswordSheet({required this.localizations, required this.theme});

  @override
  State<_ChangePasswordSheet> createState() => _ChangePasswordSheetState();
}

class _ChangePasswordSheetState extends State<_ChangePasswordSheet> {
  final _newController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _loading = false;
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  String? _error;

  @override
  void dispose() {
    _newController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final localizations = widget.localizations;
    final theme = widget.theme;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 24,
          bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(localizations.changePasswordTitle, style: theme.textTheme.headlineSmall),
            const SizedBox(height: 16),
            TextField(
              controller: _newController,
              obscureText: _obscureNew,
              autofocus: true,
              decoration: InputDecoration(
                hintText: localizations.changePasswordNewHint,
                suffixIcon: IconButton(
                  icon: Icon(_obscureNew
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined),
                  onPressed: () => setState(() => _obscureNew = !_obscureNew),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _confirmController,
              obscureText: _obscureConfirm,
              decoration: InputDecoration(
                hintText: localizations.changePasswordConfirmHint,
                suffixIcon: IconButton(
                  icon: Icon(_obscureConfirm
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined),
                  onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                ),
              ),
              onSubmitted: (_) => _save(),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(
                _error!,
                style: TextStyle(color: theme.colorScheme.error, fontSize: 12),
              ),
            ],
            const SizedBox(height: 16),
            LoadingButton(loading: _loading, onPressed: _save, label: localizations.confirm),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    final localizations = widget.localizations;
    final newPassword = _newController.text;
    final confirm = _confirmController.text;

    if (newPassword.length < 8) {
      setState(() => _error = localizations.encryptionSetupPasswordTooShort);
      return;
    }

    if (newPassword != confirm) {
      setState(() => _error = localizations.encryptionSetupPasswordMismatch);
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    final newEncryptedDataKey = await cryptographyService.reEncryptUnlockedDataKey(newPassword);

    if (!mounted) {
      return;
    }

    if (newEncryptedDataKey == null) {
      setState(() {
        _loading = false;
        _error = localizations.failure;
      });
      return;
    }

    final result = await requestService.postAuthenticatedRequest(
      'update/key',
      {'encryptedDataKey': newEncryptedDataKey},
    );

    if (!mounted) {
      return;
    }

    if (result is Failure) {
      setState(() {
        _loading = false;
        _error = (result as Failure).localizedMessage(localizations);
      });
      return;
    }

    Navigator.of(context).pop();

    scaffoldMessengerKey.currentState?.showSnackBar(
      SnackBar(content: Text(localizations.changeSuccess, textAlign: TextAlign.center)),
    );
  }
}
