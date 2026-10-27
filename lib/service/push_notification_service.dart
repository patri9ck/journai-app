// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Patrick Zwick

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../messages/app_localizations.dart';
import '../util/notifications_notifier.dart';
import '../util/storage.dart';

class PushNotificationService {
  static const _acceptedKey = 'push_notification_accepted';
  static const _topicKey = 'push_notification_topic';
  static const _promptCountKey = 'push_notification_prompt_count';
  static const _promptNextShowKey = 'push_notification_prompt_next_show';
  static const _maxPrompts = 2;

  Future<bool> isEnabled() async {
    return await storage.read(key: _acceptedKey) == 'true';
  }

  Future<AuthorizationStatus> enable() async {
    AuthorizationStatus status;

    try {
      final settings = await FirebaseMessaging.instance.requestPermission();
      status = settings.authorizationStatus;
    } on PlatformException {
      return AuthorizationStatus.denied;
    } on FirebaseException {
      return AuthorizationStatus.denied;
    }

    if (status != AuthorizationStatus.authorized) {
      return status;
    }

    await storage.write(key: _acceptedKey, value: 'true');
    newsNotificationsNotifier.value = true;

    await _subscribe();

    return status;
  }

  Future<void> disable() async {
    await _switchTopic(null);
    await storage.delete(key: _acceptedKey);
    newsNotificationsNotifier.value = false;
  }

  Future<void> tryRegisterIfPending() async {
    final accepted = await storage.read(key: _acceptedKey);

    if (accepted != 'true') {
      NotificationSettings settings;

      try {
        settings = await FirebaseMessaging.instance.getNotificationSettings();
      } on PlatformException {
        return;
      } on FirebaseException {
        return;
      }

      if (settings.authorizationStatus != AuthorizationStatus.authorized) {
        return;
      }
    }

    final subscribed = await _subscribe();

    if (subscribed && accepted != 'true') {
      await storage.write(key: _acceptedKey, value: 'true');
    }
  }

  Future<void> maybePrompt(BuildContext context) async {
    final accepted = await storage.read(key: _acceptedKey);

    if (accepted == 'true') {
      return;
    }

    final countRaw = await storage.read(key: _promptCountKey);
    final count = int.tryParse(countRaw ?? '0') ?? 0;

    if (count >= _maxPrompts) {
      return;
    }

    final nextShowRaw = await storage.read(key: _promptNextShowKey);

    if (nextShowRaw != null) {
      final nextShow = int.tryParse(nextShowRaw) ?? 0;

      if (DateTime.now().millisecondsSinceEpoch < nextShow) {
        return;
      }
    }

    if (!context.mounted) {
      return;
    }

    final localizations = AppLocalizations.of(context)!;

    final userAccepted = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(localizations.pushNotificationPromptTitle),
          content: Text(localizations.pushNotificationPromptBody),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(localizations.pushNotificationPromptDecline),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(localizations.pushNotificationPromptAccept),
            ),
          ],
        );
      },
    );

    await storage.write(key: _promptCountKey, value: (count + 1).toString());

    if (userAccepted != true) {
      final nextShow = DateTime.now().millisecondsSinceEpoch + const Duration(days: 30).inMilliseconds;
      await storage.write(key: _promptNextShowKey, value: nextShow.toString());
      return;
    }

    await enable();
  }

  Future<bool> _subscribe() {
    final language = WidgetsBinding.instance.platformDispatcher.locale.languageCode;
    final supported = AppLocalizations.supportedLocales.any((locale) => locale.languageCode == language);

    return _switchTopic('news-${supported ? language : 'en'}');
  }

  Future<bool> _switchTopic(String? topic) async {
    final currentTopic = await storage.read(key: _topicKey);

    if (currentTopic == topic) {
      return true;
    }

    try {
      if (currentTopic != null) {
        await FirebaseMessaging.instance.unsubscribeFromTopic(currentTopic);
      }

      if (topic != null) {
        await FirebaseMessaging.instance.subscribeToTopic(topic);
      }
    } on PlatformException {
      return false;
    } on FirebaseException {
      return false;
    }

    await storage.write(key: _topicKey, value: topic);

    return true;
  }
}
