// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Patrick Zwick

enum ContactType {
  email('email', 'emailAddress'),
  phone('phone', 'phoneNumber');

  final String path;
  final String field;

  const ContactType(this.path, this.field);
}
