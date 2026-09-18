import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flame/events.dart';
import 'package:flame_audio/flame_audio.dart';
import 'package:flutter/material.dart';

import '../game_themes/theme.dart';
import '../game_themes/theme_store.dart';
import '../settings_screen.dart';

/// A fully procedural button — no PNG asset required.
///
/// Draws a themed rounded chip (via [GameTheme.buttonSprite]) and a centered
/// label. Replaces the hand-authored sprite buttons across the app; each new
/// feature reuses this instead of shipping another image.
class ButtonComponent extends PositionComponent with TapCallbacks {
  String label;
  final VoidCallback onPressed;
  GameTheme theme;
  TextComponent? _labelComponent;

  ButtonComponent({
    required this.label,
    required Vector2 position,
    required Vector2 size,
    required this.onPressed,
    required this.theme,
  }) : super(position: position - size / 2, size: size, anchor: Anchor.topLeft);

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    final fontSize = size.y * 0.4;
    _labelComponent = TextComponent(
      text: label,
      position: size / 2,
      anchor: Anchor.center,
      textRenderer: TextPaint(
        style: TextStyle(
          color: theme.textColor,
          fontSize: fontSize,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
    add(_labelComponent!);
  }

  void updateTheme(GameTheme nextTheme) {
    theme = nextTheme;
    _labelComponent?.textRenderer = TextPaint(
      style: TextStyle(
        color: theme.textColor,
        fontSize: size.y * 0.4,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  @override
  void render(Canvas canvas) {
    final radius = Radius.circular(size.y * 0.22);
    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.x, size.y),
      radius,
    );
    final fill = Paint()
      ..shader = ui.Gradient.linear(const Offset(0, 0), Offset(0, size.y), [
        theme.buttonBase,
        theme.buttonHighlight,
      ]);
    canvas.drawRRect(rect, fill);
    final border = Paint()
      ..color = theme.gridColor.withValues(alpha: 0.45)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    canvas.drawRRect(rect, border);
    super.render(canvas);
  }

  @override
  void onTapDown(TapDownEvent event) {
    if (SettingsScreen.buttonSoundOn) FlameAudio.play('button.wav');
    add(
      SequenceEffect([
        ScaleEffect.to(Vector2(0.9, 0.9), EffectController(duration: 0.05)),
        ScaleEffect.to(Vector2(1.05, 1.05), EffectController(duration: 0.08)),
        ScaleEffect.to(Vector2.all(1), EffectController(duration: 0.05)),
      ]),
    );
    Future.delayed(const Duration(milliseconds: 150), onPressed);
  }
}

class SettingsIconButton extends PositionComponent with TapCallbacks {
  final VoidCallback onPressed;

  SettingsIconButton({
    required Vector2 position,
    required Vector2 size,
    required this.onPressed,
  }) : super(position: position, size: size, anchor: Anchor.center);

  @override
  void render(Canvas canvas) {
    final center = Offset(size.x / 2, size.y / 2);
    final shortestSide = math.min(size.x, size.y);
    final theme = ThemeStore.current;
    final badgeRadius = shortestSide * 0.46;
    final badgePaint = Paint()..color = theme.buttonBase.withValues(alpha: 0.92);
    final borderPaint = Paint()
      ..color = theme.gridColor.withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = shortestSide * 0.045;

    canvas.drawCircle(center, badgeRadius, badgePaint);
    canvas.drawCircle(center, badgeRadius, borderPaint);

    final gearPath = Path();
    final gearRadius = shortestSide * 0.29;
    for (var index = 0; index < 24; index++) {
      final angle = -math.pi / 2 + index * math.pi / 12;
      final radius = index.isEven ? gearRadius : gearRadius * 0.78;
      final point = Offset(
        center.dx + radius * math.cos(angle),
        center.dy + radius * math.sin(angle),
      );
      if (index == 0) {
        gearPath.moveTo(point.dx, point.dy);
      } else {
        gearPath.lineTo(point.dx, point.dy);
      }
    }
    gearPath.close();
    canvas.drawPath(gearPath, Paint()..color = theme.contrastColor);
    canvas.drawCircle(center, shortestSide * 0.115, badgePaint);
    super.render(canvas);
  }

  @override
  void onTapDown(TapDownEvent event) {
    if (SettingsScreen.buttonSoundOn) FlameAudio.play('button.wav');
    add(
      SequenceEffect([
        ScaleEffect.to(Vector2.all(0.88), EffectController(duration: 0.05)),
        ScaleEffect.to(Vector2.all(1.06), EffectController(duration: 0.08)),
        ScaleEffect.to(Vector2.all(1), EffectController(duration: 0.05)),
      ]),
    );
    Future.delayed(const Duration(milliseconds: 150), onPressed);
  }
}
