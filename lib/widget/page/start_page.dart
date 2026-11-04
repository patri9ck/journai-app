// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Patrick Zwick

import 'dart:async';
import 'dart:math';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../messages/app_localizations.dart';
import '../../service/services.dart';
import '../../util/navigation.dart';
import '../shared/full_icon.dart';
import '../sheet/login_sheet.dart';
import '../sheet/register_sheet.dart';

class StartPage extends StatefulWidget {
  const StartPage({super.key});

  @override
  State<StatefulWidget> createState() => _StartPageState();
}

class _StartPageState extends State<StartPage> {
  late List<String> _slogans;
  late int _sloganIndex;
  Timer? _sloganTimer;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final localizations = AppLocalizations.of(context)!;

    _slogans = [
      localizations.slogan1,
      localizations.slogan2,
      localizations.slogan3,
    ];

    _sloganIndex = Random().nextInt(_slogans.length);
    _scheduleSloganSwitch();
  }

  @override
  void dispose() {
    _sloganTimer?.cancel();
    super.dispose();
  }

  void _scheduleSloganSwitch() {
    _sloganTimer = Timer(const Duration(seconds: 5), () {
      if (!mounted) {
        return;
      }

      setState(() {
        _sloganIndex = (_sloganIndex + 1) % _slogans.length;
      });

      _scheduleSloganSwitch();
    });
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 30),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: FullIcon(width: 200)),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 700),
                  transitionBuilder: (child, animation) {
                    final fadeAnimation = CurvedAnimation(
                      parent: animation,
                      curve: Curves.easeInOut,
                    );

                    final slideAnimation = Tween<Offset>(
                      begin: const Offset(0, 0.12),
                      end: Offset.zero,
                    ).animate(CurvedAnimation(
                      parent: animation,
                      curve: Curves.easeOutCubic,
                    ));

                    return FadeTransition(
                      opacity: fadeAnimation,
                      child: SlideTransition(position: slideAnimation, child: child),
                    );
                  },
                  child: Text(
                    _slogans[_sloganIndex],
                    key: ValueKey(_slogans[_sloganIndex]),
                    style: theme.textTheme.displaySmall?.copyWith(
                      fontSize: 40,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ElevatedButton(
                      onPressed: () {
                        showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          useSafeArea: true,
                          builder: (_) => const RegisterSheet(),
                        );
                      },
                      child: Text(localizations.register, textAlign: TextAlign.center),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          useSafeArea: true,
                          builder: (_) => const LoginSheet(),
                        );
                      },
                      child: Text(localizations.login, textAlign: TextAlign.center),
                    ),
                    OutlinedButton(
                      onPressed: () => navigateToHome(context),
                      child: Text(localizations.withoutLogin, textAlign: TextAlign.center),
                    ),
                  ],
                ),
              ),
              Center(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: RichText(
                    textAlign: TextAlign.center,
                    text: TextSpan(
                      style: theme.textTheme.bodySmall,
                      children: [
                        TextSpan(
                          text: localizations.termsOfService,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                          recognizer: TapGestureRecognizer()
                            ..onTap = () {
                              launchUrl(
                                Uri.parse('${baseUrl}terms-of-service/'),
                                mode: LaunchMode.externalApplication,
                              );
                            },
                        ),
                        const TextSpan(text: ' - '),
                        TextSpan(
                          text: localizations.privacyPolicy,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                          recognizer: TapGestureRecognizer()
                            ..onTap = () {
                              launchUrl(
                                Uri.parse('${baseUrl}privacy-policy/'),
                                mode: LaunchMode.externalApplication,
                              );
                            },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
