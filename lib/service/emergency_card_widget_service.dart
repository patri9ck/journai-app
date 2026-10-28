// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Patrick Zwick

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:home_widget/home_widget.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../messages/app_localizations.dart';
import '../model/data.dart';
import '../model/emergency/emergency_card_content.dart';
import '../util/dynamic_palette.dart';
import '../widget/shared/emergency_card_view.dart';
import '../widget/shared/scale_to_fit.dart';

class EmergencyCardWidgetService {
  static const appGroupId = 'group.xyz.journai.app';
  static const _imageKey = 'emergency_card';
  static const _widthKey = 'emergency_card_width';
  static const _heightKey = 'emergency_card_height';
  static const _signatureKey = 'emergency_card_signature';
  static const _androidName = 'EmergencyCardWidgetProvider';
  static const _iOSName = 'EmergencyCardWidget';
  static const _defaultSize = Size(360, 380);

  Future<void> update(List<Data> healthData, {required bool metricUnits}) async {
    try {
      final localizations = _localizations();
      final content = EmergencyCardContent.fromHealthData(healthData, metricUnits: metricUnits);
      final size = await _widgetSize();
      final packageInfo = await PackageInfo.fromPlatform();
      final signature = [
        packageInfo.version,
        packageInfo.buildNumber,
        localizations.localeName,
        '${size.width}x${size.height}',
        '${emergencyCardColor.toARGB32()}',
        for (final section in [content.allergies, content.conditions, content.vitalSigns, content.healthValues, content.vaccines])
          section.join('\u0000'),
      ].join('\n');

      if (signature == await HomeWidget.getWidgetData<String>(_signatureKey)) {
        return;
      }

      final card = EmergencyCardView(localizations: localizations, content: content);

      await HomeWidget.renderFlutterWidget(
        Container(
          width: size.width,
          height: size.height,
          color: emergencyCardColor,
          child: ScaleToFit(child: card),
        ),
        key: _imageKey,
        logicalSize: size,
        pixelRatio: WidgetsBinding.instance.platformDispatcher.views.first.devicePixelRatio,
      );

      await HomeWidget.saveWidgetData<String>(_signatureKey, signature);
      await HomeWidget.updateWidget(androidName: _androidName, iOSName: _iOSName);
    } on PlatformException {
      return;
    }
  }

  Future<void> clear() async {
    try {
      await HomeWidget.saveWidgetData<String>(_imageKey, null);
      await HomeWidget.saveWidgetData<String>(_signatureKey, null);
      await HomeWidget.updateWidget(androidName: _androidName, iOSName: _iOSName);
    } on PlatformException {
      return;
    }
  }

  Future<Size> _widgetSize() async {
    final width = await HomeWidget.getWidgetData<int>(_widthKey);
    final height = await HomeWidget.getWidgetData<int>(_heightKey);

    if (width == null || height == null) {
      return _defaultSize;
    }

    return Size(width.toDouble(), height.toDouble());
  }

  bool isEmergencyCardLink(Uri? uri) => uri?.host == 'emergency-card';

  AppLocalizations _localizations() {
    final language = WidgetsBinding.instance.platformDispatcher.locale.languageCode;
    final supported = AppLocalizations.supportedLocales.any((locale) => locale.languageCode == language);

    return lookupAppLocalizations(Locale(supported ? language : 'en'));
  }
}
