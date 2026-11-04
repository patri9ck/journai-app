// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Patrick Zwick

import 'package:flutter/widgets.dart';

class AuthScope extends InheritedWidget {
  final bool isLoggedIn;

  const AuthScope({
    required this.isLoggedIn,
    required super.child,
    super.key,
  });

  static bool of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AuthScope>()?.isLoggedIn ??
      false;

  @override
  bool updateShouldNotify(AuthScope old) => old.isLoggedIn != isLoggedIn;
}
