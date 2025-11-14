import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/effects.dart';
import 'package:flame_audio/flame_audio.dart';
import 'package:flutter/material.dart' hide Route;
import 'tictactoe.dart';
import 'settings_screen.dart';

class InviteOptionsScreen extends Component
    with HasGameReference<TicTacToeGame> {
  @override
  Future<void> onLoad() async {
    await super.onLoad();

    final background = SpriteComponent()
      ..sprite = await game.loadSprite('background.png')
      ..size = game.size
      ..position = Vector2.zero()
      ..priority = 0;
    add(background);

    final genSprite = await game.loadSprite('generate_code.png');
    final joinSprite = await game.loadSprite('join_match.png');

    // Label above generate button: 'create match'
    add(
      TextComponent(
        text: 'Play with your friend',
        position: Vector2(200, 100),
        anchor: Anchor.center,
        textRenderer: TextPaint(
          style: const TextStyle(color: Colors.white, fontSize: 22),
        ),
        priority: 11010,
      ),
    );

    // Generate button
    add(
      _MenuSpriteButton(
        sprite: genSprite,
        position: Vector2(200, 500),
        onPressed: () {
          // Navigate to dedicated generate screen
          try {
            game.router.pushNamed('invite_generate');
          } catch (_) {}
        },
      ),
    );

    // Join button
    add(
      _MenuSpriteButton(
        sprite: joinSprite,
        position: Vector2(200, 420),
        onPressed: () {
          try {
            game.router.pushNamed('invite_join');
          } catch (_) {}
        },
      ),
    );

    // Return button in top-left
    final returnSprite = await game.loadSprite('return.png');
    add(
      _ReturnButton(
        sprite: returnSprite,
        position: Vector2(10, 40),
        onPressed: () => game.router.pushReplacementNamed('menu'),
      ),
    );
  }
}

class _MenuSpriteButton extends SpriteComponent with TapCallbacks {
  final VoidCallback onPressed;
  _MenuSpriteButton({
    required Sprite sprite,
    required Vector2 position,
    required this.onPressed,
  }) : super(
         sprite: sprite,
         size: Vector2(250, 64),
         position: position,
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
    Future.delayed(const Duration(milliseconds: 150), onPressed);
  }
}

class _ReturnButton extends SpriteComponent with TapCallbacks {
  final VoidCallback onPressed;
  _ReturnButton({
    required Sprite sprite,
    required Vector2 position,
    required this.onPressed,
  }) : super(
         sprite: sprite,
         size: Vector2(50, 50),
         position: position,
         anchor: Anchor.topLeft,
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
    Future.delayed(const Duration(milliseconds: 150), onPressed);
  }
}
