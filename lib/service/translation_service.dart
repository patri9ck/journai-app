// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Patrick Zwick

import 'package:flutter/services.dart';
import 'package:google_mlkit_translation/google_mlkit_translation.dart';

class TranslationService {
  static const supportedLanguages = [
    ('de', 'Deutsch'),
    ('en', 'English'),
    ('fr', 'Français'),
    ('es', 'Español'),
    ('it', 'Italiano'),
    ('pl', 'Polski'),
    ('uk', 'Українська'),
    ('ar', 'العربية'),
    ('zh', '中文'),
    ('tr', 'Türkçe'),
    ('ru', 'Русский'),
    ('ja', '日本語'),
  ];

  final _modelManager = OnDeviceTranslatorModelManager();
  final _translators = <String, OnDeviceTranslator>{};

  TranslateLanguage? _lang(String code) {
    final matches = TranslateLanguage.values.where((language) => language.bcpCode == code);

    return matches.isEmpty ? null : matches.first;
  }

  Future<bool> ensureModels(String from, String to) async {
    try {
      final fromLang = _lang(from);
      final toLang = _lang(to);

      if (fromLang == null || toLang == null) {
        return false;
      }

      final fromOk = await _modelManager.downloadModel(
        fromLang.bcpCode,
        isWifiRequired: false,
      );

      if (!fromOk) {
        return false;
      }

      final toOk = await _modelManager.downloadModel(
        toLang.bcpCode,
        isWifiRequired: false,
      );

      return toOk;
    } on PlatformException {
      return false;
    }
  }

  Future<String?> translate(String text, {required String from, required String to}) async {
    if (from == to || text.trim().isEmpty) {
      return text;
    }

    final fromLang = _lang(from);
    final toLang = _lang(to);

    if (fromLang == null || toLang == null) {
      return null;
    }

    final key = '$from>$to';
    _translators[key] ??= OnDeviceTranslator(
      sourceLanguage: fromLang,
      targetLanguage: toLang,
    );

    try {
      return await _translators[key]!.translateText(text);
    } on PlatformException {
      return null;
    }
  }

  static const _separator = '⁣';

  Future<List<String>?> translateList(
    List<String> items, {
    required String from,
    required String to,
  }) async {
    if (items.isEmpty || from == to) {
      return items;
    }

    final joined = items.join(_separator);
    final translated = await translate(joined, from: from, to: to);

    if (translated == null) {
      return null;
    }

    final lines = translated.split(_separator);

    if (lines.length != items.length) {
      final individual = <String>[];

      for (final item in items) {
        final result = await translate(item, from: from, to: to);
        individual.add(result ?? item);
      }

      return individual;
    }

    return lines;
  }

  void dispose() {
    for (final translator in _translators.values) {
      translator.close();
    }
    _translators.clear();
  }
}
