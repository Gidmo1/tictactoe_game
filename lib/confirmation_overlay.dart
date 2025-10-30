import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/effects.dart';
// package:flame/game.dart import not required; components already provides types used here
import 'package:flame_audio/flame_audio.dart';
import 'package:flutter/widgets.dart';
import 'package:tictactoe_game/settings_screen.dart';

class ConfirmationOverlay extends PositionComponent {
  final VoidCallback onYes;
  final VoidCallback onNo;

  ConfirmationOverlay({required this.onYes, required this.onNo})
    : super(
        size: Vector2(320, 180),
        anchor: Anchor.center,
        priority: 100,
        position: Vector2(160, 100),
      );

  @override
  Future<void> onLoad() async {
    final gameRef = findGame();
    if (gameRef != null) {
      position = Vector2(gameRef.size.x / 2, gameRef.size.y / 2);
    }

    // Background sprite
    final bgSprite = await (gameRef?.loadSprite('confirmation_overlay.png'));
    if (bgSprite != null) {
      add(
        SpriteComponent(
          sprite: bgSprite,
          size: size,
          anchor: Anchor.center,
          position: Vector2(160, 100),
        ),
      );
    }

    add(
      TextComponent(
        text:
            "Are you sure that you want to leave this mode? \n               You will lose the current game.",
        anchor: Anchor.topCenter,
        position: Vector2(size.x / 2, 30),
        textRenderer: TextPaint(
          style: const TextStyle(
            color: Color(0xFFFFFFFF),
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );

    // Yes button
    final yesSprite = await gameRef?.loadSprite('yes.png');
    if (yesSprite != null) {
      add(
        _OverlayButton(
          sprite: yesSprite,
          position: Vector2(size.x / 2 - 80, size.y - 50),
          onPressed: () {
            onYes();
            removeFromParent();
          },
        ),
      );
    }

    // No button
    final noSprite = await gameRef?.loadSprite('no.png');
    if (noSprite != null) {
      add(
        _OverlayButton(
          sprite: noSprite,
          position: Vector2(size.x / 2 + 80, size.y - 50),
          onPressed: () {
            onNo();
            removeFromParent();
          },
        ),
      );
    }
  }
}

class _OverlayButton extends SpriteComponent with TapCallbacks {
  final VoidCallback onPressed;

  _OverlayButton({
    required Sprite sprite,
    required Vector2 position,
    required this.onPressed,
    Vector2? size,
  }) : super(
         sprite: sprite,
         position: position,
         size: size ?? Vector2(120, 50),
         anchor: Anchor.center,
       );

  @override
  void onTapDown(TapDownEvent event) {
    if (SettingsScreen.buttonSoundOn) FlameAudio.play('button.wav');

    // Button bounce effect
    add(
      SequenceEffect([
        ScaleEffect.to(Vector2(0.9, 0.9), EffectController(duration: 0.05)),
        ScaleEffect.to(
          Vector2(1.05, 1.05),
          EffectController(duration: 0.08, curve: Curves.easeOut),
        ),
        ScaleEffect.to(
          Vector2(1.0, 1.0),
          EffectController(duration: 0.05, curve: Curves.easeIn),
        ),
      ]),
    );
    // Call the handler immediately so UX is responsive; keep the visual
    // effect running but do not delay action execution which previously
    // caused perceived slowness.
    onPressed();
  }
}
