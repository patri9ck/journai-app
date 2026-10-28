// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Patrick Zwick

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../messages/app_localizations.dart';
import '../../model/data.dart';
import '../../model/journal_entry.dart';
import '../../service/services.dart';
import '../../service/sound_service.dart';
import '../shared/document_shared.dart';

class JournalEntrySheet extends StatefulWidget {
  final int tripId;
  final DateTime date;
  final JournalEntry? entry;

  const JournalEntrySheet({super.key, required this.tripId, required this.date, this.entry});

  @override
  State<JournalEntrySheet> createState() => _JournalEntrySheetState();
}

class _JournalEntrySheetState extends State<JournalEntrySheet> {
  late final _textController = TextEditingController(text: widget.entry?.text);
  late String? _sound = widget.entry?.sound;
  bool _recording = false;
  bool _playing = false;
  bool _saving = false;
  Timer? _recordingTimer;
  StreamSubscription<void>? _playerCompletion;

  @override
  void initState() {
    super.initState();
    _playerCompletion = soundService.onPlayerComplete.listen((_) {
      if (mounted) {
        setState(() => _playing = false);
      }
    });
  }

  @override
  void dispose() {
    _recordingTimer?.cancel();
    _playerCompletion?.cancel();
    soundService.stop();
    _textController.dispose();
    super.dispose();
  }

  Future<void> _togglePlayback(String sound) async {
    if (_playing) {
      await soundService.stop();
      setState(() => _playing = false);

      return;
    }

    setState(() => _playing = true);
    await soundService.play(sound);
  }

  Future<void> _stopPlayback() async {
    if (!_playing) {
      return;
    }

    await soundService.stop();

    if (mounted) {
      setState(() => _playing = false);
    }
  }

  Future<void> _startRecording() async {
    await _stopPlayback();

    final started = await soundService.startRecording();

    if (!mounted) {
      return;
    }

    if (!started) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.journalEntryMicrophoneDenied, textAlign: TextAlign.center)),
      );

      return;
    }

    setState(() => _recording = true);
    _recordingTimer = Timer(SoundService.maximumDuration, _stopRecording);
  }

  Future<void> _stopRecording() async {
    _recordingTimer?.cancel();

    final sound = await soundService.stopRecording();

    if (mounted) {
      setState(() {
        _recording = false;
        _sound = sound ?? _sound;
      });
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);

    final entry = JournalEntry(
      id: widget.entry?.id,
      tripId: widget.tripId,
      date: widget.date,
      text: _textController.text.trim(),
      sound: _sound,
    );
    final data = Data(feature: 'JOURNAL_ENTRY', fields: entry.toFields());

    final saved = await ensureAndSave(
      context,
      () => entry.id == null ? dataService.saveData(data) : dataService.updateData(entry.id!, data),
    );

    if (!mounted) {
      return;
    }

    setState(() => _saving = false);

    if (saved) {
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            DateFormat.MMMMEEEEd(localizations.localeName).format(widget.date),
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _textController,
            minLines: 4,
            maxLines: 10,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              hintText: localizations.journalEntryTextHint,
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          if (_recording) ...[
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: SoundService.maximumDuration,
              builder: (_, value, _) => LinearProgressIndicator(value: value),
            ),
            const SizedBox(height: 8),
          ],
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: _recording ? _stopRecording : _startRecording,
                icon: Icon(_recording ? Icons.stop : Icons.mic_none, size: 18),
                label: Text(_recording ? localizations.journalEntryRecording : localizations.journalEntryRecordSound),
              ),
              if (_sound != null && !_recording)
                TextButton.icon(
                  onPressed: () => _togglePlayback(_sound!),
                  icon: Icon(_playing ? Icons.stop : Icons.play_arrow, size: 18),
                  label: Text(_playing ? localizations.journalEntryStopSound : localizations.journalEntryPlayRecording),
                ),
              if (_sound != null && !_recording)
                TextButton.icon(
                  onPressed: () async {
                    await _stopPlayback();
                    setState(() => _sound = null);
                  },
                  icon: const Icon(Icons.delete_outline, size: 18),
                  label: Text(localizations.journalEntryDeleteSound),
                ),
            ],
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _saving || _recording ? null : _save,
            child: Text(localizations.documentSave),
          ),
        ],
      ),
    );
  }
}
