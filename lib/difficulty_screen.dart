import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame_audio/flame_audio.dart';
import 'package:flutter/material.dart';
import 'package:flame/effects.dart';
import 'package:tictactoe_game/vs_ai_board.dart';
import 'package:tictactoe_game/settings_screen.dart';

class DifficultyScreen extends Component with HasGameReference {
  @override
  Future<void> onLoad() async {
    await super.onLoad();
    final bg = SpriteComponent()
      ..sprite = await game.loadSprite('background.png')
      ..size = game.size
      ..position = Vector2.zero();
    add(bg);

    final buttonSize = Vector2(180, 60);
    final startY = game.size.y / 2 - 100;
    final spacing = 80.0;

    add(
      _DifficultyButton(
        sprite: await game.loadSprite('easy.png'),
        position: Vector2(game.size.x / 2, startY),
        label: 'Easy',
        onPressed: () => _startGame('easy'),
        size: buttonSize,
      ),
    );
    add(
      _DifficultyButton(
        sprite: await game.loadSprite('medium.png'),
        position: Vector2(game.size.x / 2, startY + spacing),
        label: 'Medium',
        onPressed: () => _startGame('medium'),
        size: buttonSize,
      ),
    );
    add(
      _DifficultyButton(
        sprite: await game.loadSprite('hard.png'),
        position: Vector2(game.size.x / 2, startY + spacing * 2),
        label: 'Hard',
        onPressed: () => _startGame('hard'),
        size: buttonSize,
      ),
    );

    // Add return button
    final returnSprite = await game.loadSprite('return.png');
    final playSprite = await game.loadSprite('play.png');
    add(
      _ReturnButton(
        sprite: returnSprite,
        position: Vector2(40, 80),
        onPressed: () {
          final flameGame = findGame();
          if (flameGame != null) {
            final router = (flameGame as dynamic).router;
            router?.pushNamed('menu');
          }
        },
      ),
    );
  }

  void _startGame(String difficulty) {
    if (SettingsScreen.buttonSoundOn) FlameAudio.play('tap.wav');
    TicTacToeVsAI.selectedDifficulty = difficulty;
    final flameGame = findGame();
    if (flameGame != null) {
      final router = (flameGame as dynamic).router;
      if (router != null) {
        router.pushNamed('vsai');
      }
    }
  }
}

class _DifficultyButton extends SpriteComponent with TapCallbacks {
  final String label;
  final VoidCallback onPressed;

  _DifficultyButton({
    required Sprite sprite,
    required Vector2 position,
    required this.label,
    required this.onPressed,
    Vector2? size,
  }) : super(
         sprite: sprite,
         position: position,
         size: size ?? Vector2(180, 60),
         anchor: Anchor.center,
       );

  @override
  void onTapDown(TapDownEvent event) {
    FlameAudio.play('tap.wav');
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
         size: Vector2(60, 60),
         position: position,
         anchor: Anchor.center,
       );

  @override
  void onTapDown(TapDownEvent event) {
    FlameAudio.play('tap.wav');
    onPressed();
  }
}
