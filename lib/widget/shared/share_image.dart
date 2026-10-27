// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Patrick Zwick

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart' hide Share;

Future<void> shareWidgetAsImage(
  BuildContext context, {
  required Widget child,
  required String fileName,
  required String subject,
  double width = 360,
}) async {
  final repaintKey = GlobalKey();
  final entry = OverlayEntry(
    builder: (_) => Positioned(
      left: -5000,
      top: 0,
      width: width,
      child: RepaintBoundary(
        key: repaintKey,
        child: Material(color: Colors.transparent, child: child),
      ),
    ),
  );

  Overlay.of(context).insert(entry);

  try {
    await WidgetsBinding.instance.endOfFrame;
    await WidgetsBinding.instance.endOfFrame;

    final boundary = repaintKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;

    if (boundary == null) {
      return;
    }

    final image = await boundary.toImage(pixelRatio: 3.0);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);

    if (byteData == null) {
      return;
    }

    final file = File('${(await getTemporaryDirectory()).path}/$fileName.png');

    await file.writeAsBytes(byteData.buffer.asUint8List());

    await SharePlus.instance.share(ShareParams(files: [XFile(file.path, mimeType: 'image/png')], subject: subject));
  } finally {
    entry.remove();
  }
}

class SharePoster extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget child;

  const SharePoster({super.key, required this.title, this.subtitle, required this.child});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      color: const Color(0xFFFBF8F1),
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: theme.textTheme.headlineMedium?.copyWith(color: const Color(0xFF14161B))),
          if (subtitle != null)
            Text(subtitle!, style: theme.textTheme.bodyMedium?.copyWith(color: const Color(0xFF5B6170))),
          const SizedBox(height: 20),
          child,
          const SizedBox(height: 20),
          Align(
            alignment: Alignment.centerRight,
            child: Text('journai.xyz', style: theme.textTheme.labelSmall?.copyWith(color: const Color(0xFF5B6170))),
          ),
        ],
      ),
    );
  }
}
