// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Patrick Zwick

import 'dart:math';

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

class ScaleToFit extends SingleChildRenderObjectWidget {
  const ScaleToFit({required Widget super.child, super.key});

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderScaleToFit();
}

class _RenderScaleToFit extends RenderProxyBox {
  double _scale = 1;

  @override
  void performLayout() {
    final availableSize = constraints.biggest;
    var bestWidth = availableSize.width;
    var bestScale = 0.0;

    final minimumWidth = max(availableSize.width / 4, child!.getMinIntrinsicWidth(double.infinity));

    for (var width = minimumWidth; width <= availableSize.width * 4; width *= 1.05) {
      final height = child!.getDryLayout(BoxConstraints.tightFor(width: width)).height;
      final scale = min(availableSize.width / width, availableSize.height / height);

      if (scale > bestScale) {
        bestScale = scale;
        bestWidth = width;
      }
    }

    child!.layout(BoxConstraints.tightFor(width: bestWidth), parentUsesSize: true);

    _scale = min(availableSize.width / bestWidth, availableSize.height / child!.size.height);
    size = availableSize;
  }

  @override
  void applyPaintTransform(RenderBox child, Matrix4 transform) {
    transform.scaleByDouble(_scale, _scale, 1, 1);
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    context.pushTransform(
      needsCompositing,
      offset,
      Matrix4.diagonal3Values(_scale, _scale, 1),
      super.paint,
    );
  }
}
