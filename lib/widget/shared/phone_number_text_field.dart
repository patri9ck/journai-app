// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Patrick Zwick

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../messages/app_localizations.dart';
import '../../util/country_data.dart';

final _mobileNumberRegex = RegExp(r'^\d{8,12}$');
const _maximumMobileNumberLength = 12;

class PhoneNumberTextField extends StatefulWidget {
  final void Function(String?) _onSubmit;
  final bool _submitted;

  const PhoneNumberTextField({
    required void Function(String?) onSubmit,
    required bool submitted,
    super.key,
  }) : _onSubmit = onSubmit,
       _submitted = submitted;

  @override
  State<StatefulWidget> createState() => _PhoneNumberTextFieldState();
}

class _PhoneNumberTextFieldState extends State<PhoneNumberTextField> {
  String? _flag;
  bool _error = false;

  late final FocusNode _mobileNumberFocusNode;
  late final TextEditingController _countryCodeController;
  late final TextEditingController _mobileNumberController;

  @override
  void initState() {
    super.initState();
    _mobileNumberFocusNode = FocusNode();
    _countryCodeController = TextEditingController();
    _mobileNumberController = TextEditingController();
  }

  @override
  void dispose() {
    _mobileNumberFocusNode.dispose();
    _countryCodeController.dispose();
    _mobileNumberController.dispose();
    super.dispose();
  }

  String? _validPhoneNumber() {
    final countryCode = _countryCodeController.text;
    final mobileNumber = _mobileNumberController.text;

    if (dialCodeFlags.containsKey(countryCode) && _mobileNumberRegex.hasMatch(mobileNumber)) {
      return '+$countryCode$mobileNumber';
    }

    return null;
  }

  @override
  void didUpdateWidget(covariant PhoneNumberTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget._submitted && !oldWidget._submitted) {
      setState(() => _error = _validPhoneNumber() == null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final borderSide =
        (theme.inputDecorationTheme.border as OutlineInputBorder).borderSide;

    final countryCodeBorder = OutlineInputBorder(
      borderRadius: const BorderRadius.horizontal(left: Radius.circular(8)),
      borderSide: borderSide,
    );
    final mobileNumberBorder = OutlineInputBorder(
      borderRadius: const BorderRadius.horizontal(right: Radius.circular(8)),
      borderSide: borderSide,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              flex: 3,
              child: TextField(
                decoration: InputDecoration(
                  prefixText: '+',
                  counterText: '',
                  suffixText: _flag,
                  isDense: true,
                  hintText: '44',
                  border: countryCodeBorder,
                  focusedBorder: countryCodeBorder,
                  enabledBorder: countryCodeBorder,
                ),
                controller: _countryCodeController,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  _CountryCodeFormatter(
                    mobileNumberFocusNode: _mobileNumberFocusNode,
                    mobileNumberController: _mobileNumberController,
                  ),
                ],
                keyboardType: TextInputType.phone,
                autocorrect: false,
                maxLength: 3,
                onChanged: (countryCode) {
                  setState(() {
                    _flag = dialCodeFlags[countryCode];
                    _error = false;
                  });

                  widget._onSubmit(_validPhoneNumber());
                },
                onSubmitted: (_) => _mobileNumberFocusNode.requestFocus(),
              ),
            ),
            Expanded(
              flex: 7,
              child: TextField(
                decoration: InputDecoration(
                  counterText: '',
                  isDense: true,
                  hintText: '770 0900999',
                  border: mobileNumberBorder,
                  focusedBorder: mobileNumberBorder,
                  enabledBorder: mobileNumberBorder,
                ),
                focusNode: _mobileNumberFocusNode,
                controller: _mobileNumberController,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                keyboardType: TextInputType.phone,
                autocorrect: false,
                maxLength: _maximumMobileNumberLength + 1,
                onChanged: (_) {
                  setState(() => _error = false);

                  widget._onSubmit(_validPhoneNumber());
                },
              ),
            ),
          ],
        ),
        if (_error) ...[
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.only(left: 12),
            child: Text(
              AppLocalizations.of(context)!.invalidPhoneNumber,
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.error,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _CountryCodeFormatter extends TextInputFormatter {
  final FocusNode _mobileNumberFocusNode;
  final TextEditingController _mobileNumberController;

  _CountryCodeFormatter({
    required FocusNode mobileNumberFocusNode,
    required TextEditingController mobileNumberController,
  }) : _mobileNumberFocusNode = mobileNumberFocusNode,
       _mobileNumberController = mobileNumberController;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue _,
    TextEditingValue newValue,
  ) {
    final text = newValue.text;
    final countryCode = dialCodeFlags.keys.firstWhere(
      (code) => text.startsWith(code),
      orElse: () => '',
    );

    if (countryCode.isNotEmpty) {
      _mobileNumberFocusNode.requestFocus();

      if (countryCode.length < text.length) {
        _mobileNumberController.text = text.substring(
          countryCode.length,
          min(text.length, countryCode.length + _maximumMobileNumberLength),
        );
      }

      return TextEditingValue(text: text.substring(0, countryCode.length));
    }

    return newValue;
  }
}
