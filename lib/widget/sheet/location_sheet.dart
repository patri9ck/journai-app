// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Patrick Zwick

import 'package:flutter/material.dart';

import '../../messages/app_localizations.dart';
import '../shared/form_sheet.dart';

Future<String?> showLocationSheet(BuildContext context, String initialLocation) => showModalBottomSheet<String>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  builder: (_) => _LocationSheet(initialLocation: initialLocation),
);

class _LocationSheet extends StatefulWidget {
  final String initialLocation;

  const _LocationSheet({required this.initialLocation});

  @override
  State<_LocationSheet> createState() => _LocationSheetState();
}

class _LocationSheetState extends State<_LocationSheet> {
  late final _controller = TextEditingController(text: widget.initialLocation);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;

    return FormSheet(
      title: localizations.tripLocation,
      onSave: () => Navigator.of(context).pop(_controller.text.trim()),
      children: [
        TextField(
          controller: _controller,
          autofocus: true,
          maxLength: 40,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(hintText: localizations.tripLocationHint),
          onSubmitted: (location) => Navigator.of(context).pop(location.trim()),
        ),
      ],
    );
  }
}
