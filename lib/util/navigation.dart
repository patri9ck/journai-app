// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Patrick Zwick

import 'package:flutter/material.dart';

import '../service/services.dart';
import '../widget/page/home_page.dart';
import 'auth_notifier.dart';
import 'storage.dart';

void navigateToHome(BuildContext context) {
  storage.write(key: 'guestMode', value: 'true');

  Navigator.of(context).pushAndRemoveUntil(
    MaterialPageRoute(builder: (_) => const HomePage()),
    (_) => false,
  );
}

void navigateAfterLogin(NavigatorState navigator) {
  isLoggedInNotifier.value = true;
  subscriptionService.connect();

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
