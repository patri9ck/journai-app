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
