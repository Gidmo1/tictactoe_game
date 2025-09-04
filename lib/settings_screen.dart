import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flame/events.dart';
import 'package:flame_audio/flame_audio.dart';

class SettingsScreen extends FlameGame with TapCallbacks {
  late SpriteComponent returnButton;

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    await images.loadAll([
      'background.png',
      'settings_screen.png',
      'return.png',
    ]);

    // Background
    final background = SpriteComponent(
      sprite: await loadSprite('background.png'),
      size: size,
      position: Vector2.zero(),
      priority: 0,
    );
    add(background);

    // Settings overlay
    final settingsUi = SpriteComponent(
      sprite: await loadSprite('settings_screen.png'),
      size: Vector2(250, 250),
      position: Vector2(80, 100),
      priority: 1,
    );
    add(settingsUi);

    // Return button
    returnButton = SpriteComponent(
      sprite: await loadSprite('return.png'),
      size: Vector2(50, 50),
      position: Vector2(20, 20),
      priority: 2,
    );
    add(returnButton);
  }

  @override
  void onTapDown(TapDownEvent event) {
    super.onTapDown(event);
    FlameAudio.play('tap.wav');
  }
}
