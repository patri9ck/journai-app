// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Patrick Zwick

import 'package:flutter/material.dart';

class FullIcon extends StatelessWidget {
  final double? width;
  final double? height;

  const FullIcon({this.width, this.height, super.key});

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      Theme.of(context).brightness == Brightness.light
          ? 'assets/icon-light.png'
          : 'assets/icon-dark.png',
      width: width,
      height: height,
      fit: BoxFit.contain,
    );
  }
}
