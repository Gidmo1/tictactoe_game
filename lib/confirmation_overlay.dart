import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/effects.dart';
import 'package:flame_audio/flame_audio.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
    onPressed();
  }
}

/// A one-off overlay used to claim/select unlocked avatars.
class AvatarClaimOverlay extends PositionComponent {
  AvatarClaimOverlay()
    : super(size: Vector2(420, 320), anchor: Anchor.center, priority: 10050);

  @override
  Future<void> onLoad() async {
    final gameRef = findGame();
    if (gameRef != null) {
      position = Vector2(gameRef.size.x / 2, gameRef.size.y / 2);
    }

    // Background (claim image)
    final bgSprite = await (gameRef?.loadSprite('claim.png'));
    if (bgSprite != null) {
      add(
        SpriteComponent(
          sprite: bgSprite,
          size: size,
          anchor: Anchor.center,
          position: size / 2,
        ),
      );
    }

    // Title text
    add(
      TextComponent(
        text: 'Congratulations! You unlocked new avatars',
        anchor: Anchor.topCenter,
        position: Vector2(size.x / 2, 18),
        textRenderer: TextPaint(
          style: const TextStyle(
            color: Color(0xFFFFFFFF),
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );

    // Subtitle
    add(
      TextComponent(
        text: 'Choose one to continue using',
        anchor: Anchor.topCenter,
        position: Vector2(size.x / 2, 40),
        textRenderer: TextPaint(
          style: const TextStyle(color: Color(0xFFDDEEFF), fontSize: 12),
        ),
      ),
    );

    // Avatar names and positions
    final avatars = ['annah', 'andrew', 'david', 'piper'];
    final startX = 44.0;
    final gap = (size.x - 88) / (avatars.length - 1);
    for (var i = 0; i < avatars.length; i++) {
      final name = avatars[i];
      Sprite? sp;
      try {
        sp =
            await (gameRef?.loadSprite('$name.png') ??
                Sprite.load('$name.png'));
      } catch (_) {
        sp = null;
      }
      final pos = Vector2(startX + gap * i, size.y / 2 - 10);
      if (sp != null) {
        final btn = _AvatarButton(
          sprite: sp,
          position: pos,
          size: Vector2(72, 72),
          onPressed: () async {
            try {
              final prefs = await SharedPreferences.getInstance();
              await prefs.setString('chosen_avatar', name);
            } catch (_) {}
            // play claim sound
            try {
              if (SettingsScreen.buttonSoundOn) FlameAudio.play('button.wav');
            } catch (_) {}
            removeFromParent();
          },
        );
        add(btn);
      } else {
        // fallback to simple placeholder text button
        add(
          TextComponent(
            text: name,
            position: pos + Vector2(0, 20),
            anchor: Anchor.center,
            textRenderer: TextPaint(
              style: const TextStyle(color: Color(0xFFFFFFFF), fontSize: 12),
            ),
          ),
        );
      }
    }
  }
}

class _AvatarButton extends SpriteComponent with TapCallbacks {
  final VoidCallback onPressed;

  _AvatarButton({
    required Sprite sprite,
    required Vector2 position,
    required Vector2 size,
    required this.onPressed,
  }) : super(
         sprite: sprite,
         position: position,
         size: size,
         anchor: Anchor.center,
       );

  @override
  void onTapDown(TapDownEvent event) {
    if (SettingsScreen.buttonSoundOn) FlameAudio.play('button.wav');
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
    Future.delayed(const Duration(milliseconds: 140), onPressed);
  }
}
