import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flutter/widgets.dart';
import 'package:tictactoe_game/tictactoe.dart';
import 'settings_screen.dart';
import 'package:flame_audio/flame_audio.dart';
import 'package:flame/effects.dart';

class PrivacyOptionsScreen extends Component
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

    final settingsPageSprite = await game.loadSprite('privacy_page.png');
    add(
      SpriteComponent(
        sprite: settingsPageSprite,
        size: Vector2(370, 300),
        position: Vector2(6, 120),
      ),
    );

    final cancelSprite = await game.loadSprite('cancel.png');
    add(
      _CancelButton(
        sprite: cancelSprite,
        position: Vector2(320, 20),
        onPressed: () => game.router.pushReplacementNamed('settings'),
      ),
    );

    final privacyPolicySprite = await game.loadSprite('privacy_policy.png');
    add(
      _ArcadeButton(
        sprite: privacyPolicySprite,
        position: Vector2(68, 200),
        onPressed: () => game.router.pushReplacementNamed(''),
      ),
    );

    final dataAccessSprite = await game.loadSprite('data_access_request.png');
    add(
      _ArcadeButton(
        sprite: dataAccessSprite,
        position: Vector2(68, 270),
        onPressed: () => game.router.pushNamed(''),
      ),
    );

    final accountDeletionSprite = await game.loadSprite('account_deletion.png');
    add(
      _ArcadeButton(
        sprite: accountDeletionSprite,
        position: Vector2(68, 340),
        onPressed: () => game.router.pushNamed(''),
      ),
    );
  }
}

class _CancelButton extends SpriteComponent with TapCallbacks {
  final VoidCallback onPressed;
  _CancelButton({
    required Sprite sprite,
    required Vector2 position,
    required this.onPressed,
  }) : super(sprite: sprite, size: Vector2(50, 50), position: position);

  @override
  void onTapDown(TapDownEvent event) {
    if (SettingsScreen.buttonSoundOn) FlameAudio.play('tap.wav');
    onPressed();
  }
}

// Generic arcade button with bounce effect
class _ArcadeButton extends SpriteComponent with TapCallbacks {
  final VoidCallback onPressed;
  _ArcadeButton({
    required Sprite sprite,
    required Vector2 position,
    required this.onPressed,
  }) : super(sprite: sprite, size: Vector2(250, 40), position: position);

  @override
  void onTapDown(TapDownEvent event) {
    if (SettingsScreen.buttonSoundOn) FlameAudio.play('tap.wav');

    // Arcade bounce effect
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

    Future.delayed(Duration(milliseconds: 150), () => onPressed());
  }
}
