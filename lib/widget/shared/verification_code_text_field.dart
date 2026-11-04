// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Patrick Zwick

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class VerificationCodeTextField extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback? onSubmitted;

  const VerificationCodeTextField({
    required this.controller,
    this.onSubmitted,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      maxLength: 6,
      textAlign: TextAlign.center,
      style: theme.textTheme.headlineMedium?.copyWith(
        letterSpacing: 8,
        fontWeight: FontWeight.w500,
      ),
      decoration: const InputDecoration(
        counterText: '',
        hintText: '000000',
      ),
      onSubmitted: onSubmitted != null ? (_) => onSubmitted!() : null,
    );
  }
}
