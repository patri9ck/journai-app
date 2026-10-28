// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Patrick Zwick

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart' hide Share;

import '../../messages/app_localizations.dart';
import '../../model/poster_style.dart';
import 'stamp_font.dart';

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

const sharePosterSubtitleColor = Color(0xFF5B6170);

class PosterHeading extends StatelessWidget {
  final String title;
  final String? subtitle;
  final PosterStyle style;

  const PosterHeading({super.key, required this.title, this.subtitle, required this.style});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          style.headingOr(title),
          style: stampFontStyle(
            style.headingFont,
            theme.textTheme.headlineMedium!.copyWith(color: const Color(0xFF14161B)),
          ),
        ),
        if (subtitle != null)
          Text(subtitle!, style: theme.textTheme.bodyMedium?.copyWith(color: sharePosterSubtitleColor)),
      ],
    );
  }
}

class PosterFrameBox extends StatelessWidget {
  final PosterStyle style;
  final Widget child;

  const PosterFrameBox({super.key, required this.style, required this.child});

  @override
  Widget build(BuildContext context) {
    if (style.frame == PosterFrame.none) {
      return child;
    }


    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: style.frameColor, width: 2),
      ),
      child: style.frame == PosterFrame.double
          ? Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: style.frameColor, width: 1),
              ),
              child: child,
            )
          : child,
    );
  }
}

class PosterCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final PosterStyle style;
  final String customizeTooltip;
  final VoidCallback onCustomize;
  final VoidCallback? onShare;
  final Widget child;

  const PosterCard({
    super.key,
    required this.title,
    this.subtitle,
    required this.style,
    required this.customizeTooltip,
    required this.onCustomize,
    this.onShare,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;

    return Container(
      padding: style.frame == PosterFrame.none ? const EdgeInsets.fromLTRB(16, 12, 4, 16) : const EdgeInsets.all(8),
      decoration: BoxDecoration(color: style.background, borderRadius: BorderRadius.circular(8)),
      child: PosterFrameBox(
        style: style,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  PosterHeading(title: title, subtitle: subtitle, style: style),
                  const SizedBox(height: 12),
                  child,
                ],
              ),
            ),
            Column(
              children: [
                IconButton(
                  tooltip: customizeTooltip,
                  icon: const Icon(Icons.palette_outlined, color: sharePosterSubtitleColor),
                  onPressed: onCustomize,
                ),
                if (onShare != null)
                  IconButton(
                    tooltip: localizations.share,
                    icon: const Icon(Icons.share_outlined, color: sharePosterSubtitleColor),
                    onPressed: onShare,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class SharePoster extends StatelessWidget {
  final String title;
  final String? subtitle;
  final PosterStyle style;
  final Widget child;

  const SharePoster({
    super.key,
    required this.title,
    this.subtitle,
    this.style = const PosterStyle(),
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      color: style.background,
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PosterFrameBox(
            style: style,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                PosterHeading(title: title, subtitle: subtitle, style: style),
                const SizedBox(height: 20),
                child,
              ],
            ),
          ),
          const SizedBox(height: 20),
          Align(
            alignment: Alignment.centerRight,
            child: Text('journai.xyz', style: theme.textTheme.labelSmall?.copyWith(color: sharePosterSubtitleColor)),
          ),
        ],
      ),
    );
  }
}
