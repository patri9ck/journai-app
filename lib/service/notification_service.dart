// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Patrick Zwick

import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../messages/app_localizations.dart';
import '../model/data.dart';
import '../model/time_capsule.dart';
import '../model/trip.dart';
import '../util/document_date.dart';
import '../util/storage.dart';

class NotificationService {
  static const _enabledKey = 'settings_notifications_enabled';
  static const _channelId = 'expiry_reminders';
  static const _channelName = 'Expiry Reminders';
  static const _vaccinationReminderId = 100000;

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) {
      return;
    }

    tz.initializeTimeZones();

    try {
      final timezoneInfo = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(timezoneInfo.identifier));
    } catch (_) {
      tz.setLocalLocation(tz.UTC);
    }

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    await _plugin.initialize(
      settings: const InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      ),
    );

    _initialized = true;
  }

  Future<bool> isEnabled() async {
    final value = await storage.read(key: _enabledKey);
    return value == 'true';
  }

  Future<void> setEnabled(bool enabled) async {
    await storage.write(key: _enabledKey, value: enabled ? 'true' : 'false');
  }

  Future<bool> requestPermission() async {
    if (Platform.isAndroid) {
      final androidPlugin =
          _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      final granted = await androidPlugin?.requestNotificationsPermission();
      return granted ?? false;
    }

    if (Platform.isIOS) {
      final iosPlugin =
          _plugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
      final granted = await iosPlugin?.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
      return granted ?? false;
    }

    return true;
  }

  Future<void> clear() async {
    if (!_initialized) {
      await initialize();
    }

    await _plugin.cancelAll();
  }

  Future<void> scheduleNotifications(List<Data> data) async {
    if (!_initialized) {
      await initialize();
    }

    final pendingNotifications = await _plugin.pendingNotificationRequests();

    for (final notification in pendingNotifications) {
      if (notification.id != _vaccinationReminderId) {
        await _plugin.cancel(id: notification.id);
      }
    }

    final enabled = await isEnabled();

    if (!enabled) {
      return;
    }

    final now = DateTime.now();
    int notificationId = 0;

    final trips = Trip.fromDataList(data);

    for (final trip in trips) {
      for (final daysBefore in [30, 7]) {
        final notifyAt = trip.start.subtract(Duration(days: daysBefore));

        if (notifyAt.isBefore(now)) {
          continue;
        }

        await _schedule(
          notificationId++,
          _localizations().tripReminderTitle(trip.countryName),
          _localizations().tripReminderBody(daysBefore),
          notifyAt,
        );
      }
    }

    for (final timeCapsule in TimeCapsule.fromDataList(data)) {
      final trip = trips.where((trip) => trip.id == timeCapsule.tripId).firstOrNull;

      if (trip == null || timeCapsule.opensAt.isBefore(now)) {
        continue;
      }

      await _schedule(
        notificationId++,
        _localizations().timeCapsuleNotificationTitle(trip.countryName),
        _localizations().timeCapsuleNotificationBody,
        timeCapsule.opensAt,
      );
    }

    for (final item in data) {
      final expiryDate = _extractExpiryDate(item);

      if (expiryDate == null) {
        continue;
      }

      if (expiryDate.isBefore(now)) {
        continue;
      }

      final label = _itemLabel(item);

      for (final daysBefore in [30, 7, 1]) {
        final notifyAt = expiryDate.subtract(Duration(days: daysBefore));

        if (notifyAt.isBefore(now)) {
          continue;
        }

        await _schedule(notificationId++, label, _notificationBody(daysBefore), notifyAt);
      }
    }
  }

  Future<bool> scheduleVaccinationReminder(DateTime date, String title, String body) async {
    if (!_initialized) {
      await initialize();
    }

    final granted = await requestPermission();

    if (!granted) {
      return false;
    }

    await _schedule(_vaccinationReminderId, title, body, date);

    return true;
  }

  Future<void> _schedule(int id, String title, String body, DateTime date) => _plugin.zonedSchedule(
    id: id,
    title: title,
    body: body,
    scheduledDate: tz.TZDateTime(tz.local, date.year, date.month, date.day, 9, 0),
    notificationDetails: NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        importance: Importance.high,
        priority: Priority.high,
      ),
      iOS: const DarwinNotificationDetails(),
    ),
    androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
  );

  AppLocalizations _localizations() {
    final language = WidgetsBinding.instance.platformDispatcher.locale.languageCode;
    final supported = AppLocalizations.supportedLocales.any((locale) => locale.languageCode == language);

    return lookupAppLocalizations(Locale(supported ? language : 'en'));
  }

  DateTime? _extractExpiryDate(Data item) {
    String? dateStr;

    switch (item.feature) {
      case 'PASSPORT':
      case 'ID_CARD':
      case 'DRIVERS_LICENSE':
        dateStr = item.fields['expiryDate'] as String?;
      case 'VISA':
      case 'HEALTH_INSURANCE_CARD':
        dateStr = item.fields['validUntil'] as String?;
      case 'VACCINE':
        dateStr = item.fields['nextDate'] as String?;
    }

    return parseDocumentDate(dateStr);
  }

  String _itemLabel(Data item) {
    switch (item.feature) {
      case 'PASSPORT':
        final name = item.fields['givenNames'] as String?;
        return name != null && name.isNotEmpty ? 'Passport ($name)' : 'Passport';
      case 'ID_CARD':
        return 'ID Card';
      case 'DRIVERS_LICENSE':
        return "Driver's License";
      case 'VISA':
        final country = item.fields['country'] as String?;
        return country != null && country.isNotEmpty ? 'Visa ($country)' : 'Visa';
      case 'HEALTH_INSURANCE_CARD':
        final name = item.fields['insuranceName'] as String?;
        return name != null && name.isNotEmpty
            ? 'Health Insurance ($name)'
            : 'Health Insurance Card';
      case 'VACCINE':
        final name = item.fields['name'] as String?;
        return name != null && name.isNotEmpty
            ? 'Vaccination: $name'
            : 'Vaccination due';
      default:
        return item.feature;
    }
  }

  String _notificationBody(int daysBefore) {
    if (daysBefore == 1) {
      return 'Expires tomorrow';
    }

    return 'Expires in $daysBefore days';
  }
}
