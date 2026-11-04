// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Patrick Zwick

import 'dart:async';

import 'package:flutter/material.dart';

import '../../messages/app_localizations.dart';
import '../../model/place_suggestion.dart';
import '../../service/services.dart';
import '../shared/sheet_handle.dart';

Future<String?> showLocationSheet(BuildContext context, String initialLocation, {required String countryCode}) =>
    showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _LocationSheet(initialLocation: initialLocation, countryCode: countryCode),
    );

class _LocationSheet extends StatefulWidget {
  final String initialLocation;
  final String countryCode;

  const _LocationSheet({required this.initialLocation, required this.countryCode});

  @override
  State<_LocationSheet> createState() => _LocationSheetState();
}

class _LocationSheetState extends State<_LocationSheet> {
  static const _debounce = Duration(milliseconds: 500);

  late final _controller = TextEditingController(text: widget.initialLocation);
  List<PlaceSuggestion> _suggestions = [];
  bool _searching = false;
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();

    if (widget.initialLocation.trim().length >= 2) {
      _search(widget.initialLocation.trim());
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounceTimer?.cancel();

    final query = value.trim();

    if (query.length < 2) {
      setState(() {
        _suggestions = [];
        _searching = false;
      });

      return;
    }

    setState(() => _searching = true);
    _debounceTimer = Timer(_debounce, () => _search(query));
  }

  Future<void> _search(String query) async {
    final suggestions = await geocodingService.searchPlaces(query, widget.countryCode);

    if (!mounted || _controller.text.trim() != query) {
      return;
    }

    setState(() {
      _suggestions = suggestions;
      _searching = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final query = _controller.text.trim();
    final showCustomEntry = query.isNotEmpty && !_searching && _suggestions.isEmpty;

    return DraggableScrollableSheet(
      initialChildSize: 0.92,
      minChildSize: 0.5,
      maxChildSize: 1.0,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            const SheetHandle(),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: TextField(
                controller: _controller,
                maxLength: 40,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  hintText: localizations.tripLocationHint,
                  prefixIcon: const Icon(Icons.search),
                ),
                onChanged: _onChanged,
              ),
            ),
            if (_searching) const LinearProgressIndicator(),
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                itemCount: _suggestions.length + (showCustomEntry ? 1 : 0),
                itemBuilder: (context, index) {
                  if (showCustomEntry) {
                    return ListTile(
                      leading: const Icon(Icons.edit_location_outlined),
                      title: Text(query),
                      onTap: () => Navigator.of(context).pop(query),
                    );
                  }

                  final suggestion = _suggestions[index];

                  return ListTile(
                    leading: const Icon(Icons.location_on_outlined),
                    title: Text(suggestion.name),
                    subtitle: suggestion.detail.isEmpty
                        ? null
                        : Text(suggestion.detail, maxLines: 1, overflow: TextOverflow.ellipsis),
                    onTap: () => Navigator.of(context).pop(suggestion.name),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}
