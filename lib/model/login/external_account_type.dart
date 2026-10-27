// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Patrick Zwick

enum ExternalAccountType {
  google('google'),
  apple('apple');

  final String path;

  const ExternalAccountType(this.path);
}
