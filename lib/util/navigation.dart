// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Patrick Zwick

import 'dart:async';

import 'package:flutter/material.dart';

import '../service/services.dart';
import '../widget/page/home_page.dart';
import 'auth_notifier.dart';
import 'storage.dart';

Future<void> navigateToHome(BuildContext context) async {
  await storage.write(key: 'guestMode', value: 'true');

  if (!context.mounted) {
    return;
  }

  Navigator.of(context).pushAndRemoveUntil(
    MaterialPageRoute(builder: (_) => const HomePage()),
    (_) => false,
  );
}

Future<void> navigateAfterLogin(NavigatorState navigator) async {
  isLoggedInNotifier.value = true;

  unawaited(subscriptionService.connect());

  navigator.pushAndRemoveUntil(
    MaterialPageRoute(builder: (_) => const HomePage()),
    (_) => false,
  );
}

Route slideUpRoute(Widget page) {
  return PageRouteBuilder(
    pageBuilder: (context, animation, secondaryAnimation) => page,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      return SlideTransition(
        position: Tween(
          begin: const Offset(0.0, 1.0),
          end: Offset.zero,
        ).animate(CurvedAnimation(parent: animation, curve: Curves.ease)),
        child: child,
      );
    },
  );
}
