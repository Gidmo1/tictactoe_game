import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flame/events.dart';

class SettingsScreen extends FlameGame with TapCallbacks {
  late SpriteComponent returnButton;

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    final background = SpriteComponent()
      ..sprite = await loadSprite('background.png')
      ..size = size
      ..position = Vector2.zero();
    add(background);

    final settingsImage = SpriteComponent()
      ..sprite = await loadSprite('settings_screen.png')
      ..size = size
      ..position = Vector2.zero();
    add(settingsImage);

    returnButton = SpriteComponent()
      ..sprite = await loadSprite('return.png')
      ..size = Vector2(50, 50)
      ..position = Vector2(20, 20);
    add(returnButton);
  }

  @override
  void onTapDown(TapDownEvent event) {
    // check if return button was tapped
    if (returnButton.toRect().contains(event.localPosition.toOffset())) {
      (HasGameReference as dynamic).router.pushReplacementNamed('tictactoe');
    }
    super.onTapDown(event);
  }
}
