// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Patrick Zwick

import 'dart:convert';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

class SoundService {
  static const maximumDuration = Duration(seconds: 5);

  final _recorder = AudioRecorder();
  final _player = AudioPlayer();

  Stream<void> get onPlayerComplete => _player.onPlayerComplete;

  Future<bool> startRecording() async {
    if (!await _recorder.hasPermission()) {
      return false;
    }

    await _recorder.start(
      const RecordConfig(encoder: AudioEncoder.aacLc, bitRate: 32000, sampleRate: 22050, numChannels: 1),
      path: await _soundPath('recording'),
    );

    return true;
  }

  Future<String?> stopRecording() async {
    final path = await _recorder.stop();

    if (path == null) {
      return null;
    }

    final file = File(path);
    final sound = base64Encode(await file.readAsBytes());

    await file.delete();

    return sound;
  }

  Future<void> play(String sound) async {
    final file = File(await _soundPath('playback'));

    await file.writeAsBytes(base64Decode(sound));
    await _player.play(DeviceFileSource(file.path));
  }

  Future<void> stop() => _player.stop();

  Future<String> _soundPath(String name) async => '${(await getTemporaryDirectory()).path}/$name.m4a';
}
