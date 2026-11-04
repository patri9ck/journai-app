// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Patrick Zwick

class Data {
  final int? id;
  final String feature;
  final Map<String, dynamic> fields;
  final int? profileId;

  Data({this.id, required this.feature, required this.fields, this.profileId});

  factory Data.fromJson(Map<String, dynamic> json) => Data(
    id: json['id'] as int?,
    feature: json['feature'] as String,
    fields: Map<String, dynamic>.from((json['fields'] as Map?) ?? {}),
    profileId: json['profileId'] as int?,
  );

  Map<String, dynamic> toJson() => {
    if (id != null) 'id': id,
    'feature': feature,
    'fields': fields,
    if (profileId != null) 'profileId': profileId,
  };
}
