// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Patrick Zwick

import 'package:flutter/material.dart';

import '../../messages/app_localizations.dart';

final _regex = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
const _maximumLength = 254;

class EmailAddressTextField extends StatefulWidget {
  final void Function(String?) _onSubmit;
  final bool _submitted;

  const EmailAddressTextField({
    required void Function(String?) onSubmit,
    required bool submitted,
    super.key,
  }) : _onSubmit = onSubmit,
       _submitted = submitted;

  @override
  State<StatefulWidget> createState() => _EmailAddressTextFieldState();
}

class _EmailAddressTextFieldState extends State<EmailAddressTextField> {
  bool _showError = false;
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool _isValid(String text) =>
      _regex.hasMatch(text) && text.length <= _maximumLength;

  @override
  void didUpdateWidget(covariant EmailAddressTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget._submitted && !oldWidget._submitted) {
      setState(() => _showError = !_isValid(_controller.text));
    }
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      decoration: InputDecoration(
        counterText: '',
        isDense: true,
        hintText: AppLocalizations.of(context)!.emailAddressHint,
        errorText: _showError
            ? AppLocalizations.of(context)!.invalidEmailAddress
            : null,
      ),
      keyboardType: TextInputType.emailAddress,
      autocorrect: false,
      maxLength: _maximumLength,
      onChanged: (text) {
        if (_showError) {
          setState(() => _showError = false);
        }

        final validEmail = _isValid(text) ? text : null;
        widget._onSubmit(validEmail);
      },
    );
  }
}
