// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Patrick Zwick

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../messages/app_localizations.dart';
import '../../model/data.dart';
import '../../model/result.dart';
import '../../model/time_capsule.dart';
import '../../model/trip.dart';
import '../../service/services.dart';
import '../../util/country_name.dart';
import '../shared/document_shared.dart';
import '../shared/share_image.dart';
import '../shared/travel_stamp.dart';

class TimeCapsulePage extends StatefulWidget {
  final Trip trip;
  final TimeCapsule? timeCapsule;
  final double? temperature;

  const TimeCapsulePage({super.key, required this.trip, this.timeCapsule, this.temperature});

  @override
  State<TimeCapsulePage> createState() => _TimeCapsulePageState();
}

class _TimeCapsulePageState extends State<TimeCapsulePage> {
  final _textController = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  DateTime _today() {
    final now = DateTime.now();

    return DateTime(now.year, now.month, now.day);
  }

  Future<void> _seal() async {
    setState(() => _saving = true);

    final today = _today();
    final timeCapsule = TimeCapsule(
      tripId: widget.trip.id!,
      text: _textController.text.trim(),
      writtenAt: today,
      opensAt: DateTime(today.year + 1, today.month, today.day),
    );

    final saved = await ensureAndSave(
      context,
      () => dataService.saveData(Data(feature: 'TIME_CAPSULE', fields: timeCapsule.toFields())),
    );

    if (saved) {
      await dataService.getData();
      await notificationService.scheduleNotifications(await dataService.getCachedDataOfAllProfiles());
    }

    if (!mounted) {
      return;
    }

    setState(() => _saving = false);

    if (saved) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _delete() async {
    final localizations = AppLocalizations.of(context)!;

    final confirmed = await confirmDelete(
      context,
      localizations.timeCapsuleDeleteConfirm,
      localizations.documentDeleteConfirmYes,
    );

    if (!confirmed || !mounted) {
      return;
    }

    final result = await dataService.deleteData(widget.timeCapsule!.id!);

    if (!mounted) {
      return;
    }

    if (result is Failure<void>) {
      result.show(localizations);

      return;
    }

    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final timeCapsule = widget.timeCapsule;
    final dateFormat = DateFormat.yMMMd(localizations.localeName);
    final postcard = timeCapsule == null
        ? null
        : _Postcard(
            trip: widget.trip,
            timeCapsule: timeCapsule,
            temperature: widget.temperature,
            open: timeCapsule.isOpen(_today()),
          );

    return Scaffold(
      appBar: AppBar(
        title: Text(localizations.tripTimeCapsuleTitle),
        actions: [
          if (postcard != null && postcard.open)
            IconButton(
              tooltip: localizations.share,
              icon: const Icon(Icons.share_outlined),
              onPressed: () => shareWidgetAsImage(
                context,
                fileName: 'time-capsule',
                subject: localizations.tripTimeCapsuleTitle,
                child: SharePoster(title: tripPlaceName(context, widget.trip), child: postcard),
              ),
            ),
          if (timeCapsule != null)
            IconButton(
              tooltip: localizations.documentDeleteConfirmYes,
              icon: const Icon(Icons.delete_outline),
              onPressed: _delete,
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
        children: [
          if (postcard == null) ...[
            Text(localizations.timeCapsuleHint, style: theme.textTheme.bodyMedium),
            const SizedBox(height: 16),
            TextField(
              controller: _textController,
              minLines: 8,
              maxLines: 16,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: localizations.timeCapsuleTextHint,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            ListenableBuilder(
              listenable: _textController,
              builder: (_, _) => FilledButton.icon(
                onPressed: _saving || _textController.text.trim().isEmpty ? null : _seal,
                icon: const Icon(Icons.lock_outline, size: 18),
                label: Text(localizations.timeCapsuleSeal),
              ),
            ),
          ] else ...[
            postcard,
            if (!postcard.open) ...[
              const SizedBox(height: 16),
              Text(
                localizations.tripTimeCapsuleOpensOn(dateFormat.format(timeCapsule!.opensAt)),
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium,
              ),
              Text(
                localizations.timeCapsuleDaysLeft(timeCapsule.opensAt.difference(_today()).inDays),
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium,
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _Postcard extends StatelessWidget {
  final Trip trip;
  final TimeCapsule timeCapsule;
  final double? temperature;
  final bool open;

  const _Postcard({required this.trip, required this.timeCapsule, required this.temperature, required this.open});

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    const inkColor = Color(0xFF2B2B33);

    return AspectRatio(
      aspectRatio: 1.45,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFFBF6EA),
          borderRadius: BorderRadius.circular(6),
          boxShadow: const [BoxShadow(color: Color(0x26000000), blurRadius: 10, offset: Offset(0, 3))],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: open
                  ? SingleChildScrollView(
                      child: Text(
                        timeCapsule.text,
                        style: GoogleFonts.instrumentSerif(
                          textStyle: theme.textTheme.titleMedium?.copyWith(color: inkColor, fontStyle: FontStyle.italic),
                        ),
                      ),
                    )
                  : const Center(child: Icon(Icons.lock_outline, size: 40, color: inkColor)),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                TravelStamp(trip: trip, temperature: temperature, size: 72),
                const Spacer(),
                Text(
                  localizations.timeCapsuleFrom(
                    tripPlaceName(context, trip),
                    DateFormat.yMMMd(localizations.localeName).format(timeCapsule.writtenAt),
                  ),
                  style: theme.textTheme.bodySmall?.copyWith(color: inkColor),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
