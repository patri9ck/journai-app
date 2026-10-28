// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Patrick Zwick

import 'package:flutter/widgets.dart';

import '../model/data.dart';
import '../model/memories_style.dart';
import '../service/services.dart';
import '../widget/shared/document_shared.dart';

Future<MemoriesStyle> loadMemoriesStyle() async =>
    MemoriesStyle.fromDataList(await dataService.getCachedData(['MEMORIES_STYLE']));

Future<MemoriesStyle?> saveMemoriesStyle(BuildContext context, MemoriesStyle style) async {
  final data = Data(feature: 'MEMORIES_STYLE', fields: style.toFields());

  final saved = await ensureAndSave(
    context,
    () => style.id == null ? dataService.saveData(data) : dataService.updateData(style.id!, data),
  );

  if (!saved) {
    return null;
  }

  await dataService.getData();

  return loadMemoriesStyle();
}
