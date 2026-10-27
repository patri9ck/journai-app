// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Patrick Zwick

import 'package:flutter/material.dart';

class TripStripe {
  final Color color;
  final bool rainy;
  final bool hasMemory;

  const TripStripe({required this.color, this.rainy = false, this.hasMemory = false});
}

class TripStripes extends StatelessWidget {
  final List<TripStripe> stripes;
  final double height;
  final double spacing;
  final int? selectedIndex;
  final ValueChanged<int>? onSelected;

  const TripStripes({
    super.key,
    required this.stripes,
    this.height = 72,
    this.spacing = 3,
    this.selectedIndex,
    this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SizedBox(
      height: height,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var index = 0; index < stripes.length; index++) ...[
            if (index > 0) SizedBox(width: spacing),
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onSelected == null ? null : () => onSelected!(index),
                child: Column(
                  children: [
                    Expanded(
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        decoration: BoxDecoration(
                          color: stripes[index].color,
                          borderRadius: BorderRadius.circular(4),
                          border: selectedIndex == index
                              ? Border.all(color: theme.colorScheme.onSurface, width: 2)
                              : null,
                        ),
                        child: stripes[index].rainy ? const CustomPaint(painter: _RainPainter()) : null,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      width: 5,
                      height: 5,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: stripes[index].hasMemory ? theme.colorScheme.primary : Colors.transparent,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _RainPainter extends CustomPainter {
  const _RainPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white.withValues(alpha: 0.55);

    for (var y = 6.0; y < size.height; y += 9) {
      for (var x = (y ~/ 9).isEven ? size.width / 3 : size.width * 2 / 3; x < size.width; x += size.width) {
        canvas.drawCircle(Offset(x, y), 1.4, paint);
      }
    }
  }

  @override
  bool shouldRepaint(_RainPainter oldDelegate) => false;
}
