// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Patrick Zwick

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:home_widget/home_widget.dart';
import 'package:google_fonts/google_fonts.dart';

import 'messages/app_localizations.dart';
import 'service/services.dart';
import 'util/auth_notifier.dart';
import 'util/auth_scope.dart';
import 'util/dynamic_palette.dart';
import 'util/firebase_options.dart';
import 'util/navigator_key.dart';
import 'util/scaffold_messenger_key.dart';
import 'util/storage.dart';
import 'util/notifications_notifier.dart';
import 'service/emergency_card_widget_service.dart';
import 'util/emergency_card_notifier.dart';
import 'util/profile_notifier.dart';
import 'util/units_notifier.dart';
import 'widget/page/home_page.dart';
import 'widget/page/start_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  GoogleFonts.config.allowRuntimeFetching = false;

  final options = firebaseOptions;

  if (options != null) {
    await Firebase.initializeApp(options: options);
  }

  await googleAccountService.initialize();
  await notificationService.initialize();

  pushNotificationService.tryRegisterIfPending();

  final refreshToken = await storage.read(key: 'refreshToken');
  final guestMode = await storage.read(key: 'guestMode');
  final units = await storage.read(key: 'settings_units_metric');

  final newsNotifications = await pushNotificationService.isEnabled();

  await loadSelectedProfile();
  await HomeWidget.setAppGroupId(EmergencyCardWidgetService.appGroupId);

  emergencyCardRequestedNotifier.value =
      emergencyCardWidgetService.isEmergencyCardLink(await HomeWidget.initiallyLaunchedFromHomeWidget());

  HomeWidget.widgetClicked.listen((uri) {
    if (emergencyCardWidgetService.isEmergencyCardLink(uri)) {
      emergencyCardRequestedNotifier.value = true;
    }
  });

  isLoggedInNotifier.value = refreshToken != null;

  if (refreshToken != null) {
    subscriptionService.connect();
  }
  metricUnitsNotifier.value = units != 'false';
  newsNotificationsNotifier.value = newsNotifications;

  dynamicPalette = await loadDynamicPalette();

  runApp(App(showHome: refreshToken != null || guestMode == 'true'));
}

class App extends StatelessWidget {
  final bool showHome;

  const App({required this.showHome, super.key});

  static const _primaryLight = brandColor;
  static const _primaryDark = Color(0xFF5A9CF5);

  static TextTheme _textTheme(Color color, Color muted) {
    TextStyle serif(TextStyle base) =>
        GoogleFonts.instrumentSerif(textStyle: base.copyWith(color: color));
    TextStyle sans(TextStyle base) =>
        GoogleFonts.inter(textStyle: base.copyWith(color: color));

    return TextTheme(
      displayLarge: serif(const TextStyle(fontSize: 57, letterSpacing: -0.25)),
      displayMedium: serif(const TextStyle(fontSize: 45)),
      displaySmall: serif(const TextStyle(fontSize: 36)),
      headlineLarge: sans(const TextStyle(fontSize: 32, fontWeight: FontWeight.w600)),
      headlineMedium: sans(const TextStyle(fontSize: 28, fontWeight: FontWeight.w600)),
      headlineSmall: sans(const TextStyle(fontSize: 24, fontWeight: FontWeight.w600)),
      titleLarge: sans(const TextStyle(fontSize: 22, fontWeight: FontWeight.w600)),
      titleMedium: sans(const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
      titleSmall: sans(const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
      bodyLarge: sans(const TextStyle(fontSize: 16)),
      bodyMedium: sans(const TextStyle(fontSize: 14)),
      bodySmall: sans(TextStyle(fontSize: 12, color: muted)),
      labelLarge: sans(const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
      labelMedium: sans(const TextStyle(fontSize: 12)),
      labelSmall: sans(TextStyle(fontSize: 11, color: muted)),
    );
  }

  static ThemeData _buildTheme(Brightness brightness) {
    final isLight = brightness == Brightness.light;
    final palette = dynamicPalette;
    final dynamicScheme = palette == null
        ? null
        : ColorScheme.fromSeed(seedColor: palette.lightPrimary, brightness: brightness).copyWith(
            primary: isLight ? palette.lightPrimary : palette.darkPrimary,
            onPrimary: Colors.white,
          );
    final primary = dynamicScheme?.primary ?? (isLight ? _primaryLight : _primaryDark);
    final onPrimary = dynamicScheme?.onPrimary ?? Colors.white;
    final bgColor = dynamicScheme?.surface ?? (isLight ? const Color(0xFFFFFFFF) : const Color(0xFF1B1B1B));
    final textColor = dynamicScheme?.onSurface ?? (isLight ? const Color(0xFF0A0A0A) : const Color(0xFFF0F0F0));
    final mutedColor = dynamicScheme?.onSurfaceVariant ?? (isLight ? const Color(0xFF5D5D5D) : const Color(0xFF989898));
    final borderColor = dynamicScheme?.outlineVariant ?? (isLight ? const Color(0xFFE0E0E0) : const Color(0xFF333333));
    final hintColor = dynamicScheme?.outline ?? (isLight ? const Color(0xFF989898) : const Color(0xFF666666));
    final sheetBg = dynamicScheme?.surfaceContainerLow ?? (isLight ? const Color(0xFFFFFFFF) : const Color(0xFF222222));
    final snackBg = dynamicScheme?.inverseSurface ?? (isLight ? const Color(0xFF0A0A0A) : const Color(0xFF252525));
    final snackTextColor = dynamicScheme?.onInverseSurface ?? Colors.white;

    const borderRadiusSm = BorderRadius.all(Radius.circular(8));
    final buttonShape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(100));

    final inputBorder = OutlineInputBorder(
      borderRadius: borderRadiusSm,
      borderSide: BorderSide(color: borderColor),
    );
    final focusedBorder = OutlineInputBorder(
      borderRadius: borderRadiusSm,
      borderSide: BorderSide(color: primary),
    );

    return ThemeData(
      brightness: brightness,
      colorScheme: dynamicScheme ??
          ColorScheme(
            brightness: brightness,
            primary: primary,
            onPrimary: onPrimary,
            secondary: primary,
            onSecondary: onPrimary,
            error: const Color(0xFFE74C3C),
            onError: Colors.white,
            surface: bgColor,
            onSurface: textColor,
            outline: borderColor,
          ),
      scaffoldBackgroundColor: bgColor,
      textTheme: _textTheme(textColor, mutedColor),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: onPrimary,
          shape: buttonShape,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: textColor,
          side: BorderSide(color: borderColor),
          shape: buttonShape,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        prefixStyle: TextStyle(color: textColor),
        border: inputBorder,
        focusedBorder: focusedBorder,
        enabledBorder: inputBorder,
        suffixIconColor: textColor,
        hintStyle: GoogleFonts.inter(color: hintColor),
      ),
      textSelectionTheme: TextSelectionThemeData(
        selectionColor: primary.withValues(alpha: 0.3),
        cursorColor: primary,
        selectionHandleColor: primary,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: snackBg,
        contentTextStyle: GoogleFonts.inter(color: snackTextColor, fontSize: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        behavior: SnackBarBehavior.floating,
        elevation: 0,
        insetPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: primary),
      bottomSheetTheme: BottomSheetThemeData(backgroundColor: sheetBg),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: isLoggedInNotifier,
      builder: (context, isLoggedIn, _) {
        return AuthScope(
          isLoggedIn: isLoggedIn,
          child: MaterialApp(
            navigatorKey: navigatorKey,
            scaffoldMessengerKey: scaffoldMessengerKey,
            debugShowCheckedModeBanner: false,
            title: 'Journai',
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            theme: _buildTheme(Brightness.light),
            darkTheme: _buildTheme(Brightness.dark),
            home: showHome ? const HomePage() : const StartPage(),
          ),
        );
      },
    );
  }
}

