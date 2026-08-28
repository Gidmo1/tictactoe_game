import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flutter/material.dart';

import '../game_themes/theme.dart';

class OrnateOverlayPanel extends PositionComponent {
  final GameTheme theme;

  OrnateOverlayPanel({required Vector2 size, required this.theme})
    : super(size: size);

  @override
  void render(Canvas canvas) {
    final outer = RRect.fromRectAndRadius(
      Rect.fromLTWH(1, 1, size.x - 2, size.y - 2),
      const Radius.circular(14),
    );
    final fill = Paint()
      ..shader = ui.Gradient.linear(const Offset(0, 0), Offset(0, size.y), [
        theme.buttonBase,
        theme.boardBackground,
      ]);
    canvas.drawRRect(outer, fill);

    final woodBorder = Paint()
      ..color = const Color(0xFF8B5E3C)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5;
    canvas.drawRRect(outer, woodBorder);

    final goldBorder = Paint()
      ..color = const Color(0xFFD4AF37)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawRRect(outer, goldBorder);
    super.render(canvas);
  }
}

class InputBlockingDim extends RectangleComponent with TapCallbacks {
  InputBlockingDim({
    required Vector2 size,
    required Color color,
    required int priority,
  }) : super(size: size, paint: Paint()..color = color, priority: priority);

  @override
  void onTapDown(TapDownEvent event) {
    event.continuePropagation = false;
  }
}
