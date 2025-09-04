import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame_audio/flame_audio.dart';
import 'package:flutter/widgets.dart';
import 'package:tictactoe_game/tictactoe.dart';

class SettingsScreen extends Component
    with HasGameReference<TicTacToeGame>, TapCallbacks {
  @override
  Future<void> onLoad() async {
    await super.onLoad();

    final backgroundSprite = await game.loadSprite('background.png');
    add(
      SpriteComponent(
        sprite: backgroundSprite,
        size: game.size,
        position: Vector2.zero(),
      ),
    );

    final overlaySprite = await game.loadSprite('settings_screen.png');
    add(
      SpriteComponent(
        sprite: overlaySprite,
        size: Vector2(250, 250),
        position: Vector2(80, 100),
      ),
    );

    /*final overlaySprite = await game.loadSprite('settings_screen.png');
add(
  _PushableOverlay(
    sprite: overlaySprite,
    size: Vector2(250, 250),
    position: Vector2(80, 100),
    onPressed: () {
      print("Overlay pushed!");
    },
  ),
);*/

    final returnSprite = await game.loadSprite('return.png');
    add(
      _ReturnButton(
        sprite: returnSprite,
        position: Vector2(20, 20),
        onPressed: () => game.router.pushReplacementNamed('tictactoe'),
      ),
    );
  }
}

class _ReturnButton extends SpriteComponent with TapCallbacks {
  final VoidCallback onPressed;
  _ReturnButton({
    required Sprite sprite,
    required Vector2 position,
    required this.onPressed,
  }) : super(sprite: sprite, size: Vector2(50, 50), position: position);

  @override
  void onTapDown(TapDownEvent event) {
    // Play the tap sound
    FlameAudio.play('tap.wav');

    // Run the assigned action
    onPressed();
  }
}
