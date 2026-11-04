// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Patrick Zwick

import 'package:flutter/foundation.dart';

import 'storage.dart';

const _selectedProfileKey = 'selected_profile';

final selectedProfileNotifier = ValueNotifier<int?>(null);

Future<void> loadSelectedProfile() async {
  selectedProfileNotifier.value = int.tryParse(await storage.read(key: _selectedProfileKey) ?? '');
}

Future<void> selectProfile(int? profileId) async {
  if (profileId == null) {
    await storage.delete(key: _selectedProfileKey);
  } else {
    await storage.write(key: _selectedProfileKey, value: profileId.toString());
  }

  selectedProfileNotifier.value = profileId;
}
