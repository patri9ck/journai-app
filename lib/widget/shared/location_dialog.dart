// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Patrick Zwick

import 'package:flutter/material.dart';

import '../../messages/app_localizations.dart';

Future<String?> showLocationDialog(BuildContext context, String initialLocation) =>
    showDialog<String>(context: context, builder: (_) => _LocationDialog(initialLocation: initialLocation));

class _LocationDialog extends StatefulWidget {
  final String initialLocation;

  const _LocationDialog({required this.initialLocation});

  @override
  State<_LocationDialog> createState() => _LocationDialogState();
}

class _LocationDialogState extends State<_LocationDialog> {
  late final _controller = TextEditingController(text: widget.initialLocation);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;

    return AlertDialog(
      title: Text(localizations.tripLocation),
      content: TextField(
        controller: _controller,
        autofocus: true,
        maxLength: 40,
        textCapitalization: TextCapitalization.words,
        decoration: InputDecoration(hintText: localizations.tripLocationHint),
        onSubmitted: (location) => Navigator.of(context).pop(location.trim()),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(localizations.back),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(_controller.text.trim()),
          child: Text(localizations.documentSave),
        ),
      ],
    );
  }
}
