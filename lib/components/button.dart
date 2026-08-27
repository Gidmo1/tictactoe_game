import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flame/events.dart';
import 'package:flame_audio/flame_audio.dart';
import 'package:flutter/material.dart';

import '../game_themes/theme.dart';
import '../settings_screen.dart';

/// A fully procedural button — no PNG asset required.
///
/// Draws a themed rounded chip (via [GameTheme.buttonSprite]) and a centered
/// label. Replaces the hand-authored sprite buttons across the app; each new
/// feature reuses this instead of shipping another image.
class ButtonComponent extends PositionComponent with TapCallbacks {
  String label;
  final VoidCallback onPressed;
  final GameTheme theme;

  ButtonComponent({
    required this.label,
    required Vector2 position,
    required Vector2 size,
    required this.onPressed,
    required this.theme,
  }) : super(
         position: position - size / 2,
         size: size,
         anchor: Anchor.topLeft,
       );

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    final chip = SpriteComponent(
      sprite: await theme.buttonSprite(size.x, size.y),
      size: size,
      position: Vector2.zero(),
    );
    add(chip);

    final fontSize = size.y * 0.4;
    add(
      TextComponent(
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
      ),
    );
  }

  @override
  void onTapDown(TapDownEvent event) {
    if (SettingsScreen.buttonSoundOn) FlameAudio.play('button.wav');
    add(
      SequenceEffect([
        ScaleEffect.to(Vector2(0.9, 0.9), EffectController(duration: 0.05)),
        ScaleEffect.to(
          Vector2(1.05, 1.05),
          EffectController(duration: 0.08),
        ),
        ScaleEffect.to(Vector2.all(1), EffectController(duration: 0.05)),
      ]),
    );
    Future.delayed(const Duration(milliseconds: 150), onPressed);
  }
}