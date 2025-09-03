import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart' hide Route;
import 'package:flame_audio/flame_audio.dart';
import 'package:tictactoe_game/settings_screen.dart';
import 'firebase.dart';
import 'board.dart';

class TicTacToeGame extends FlameGame
    with HasKeyboardHandlerComponents, TapCallbacks {
  late final RouterComponent router;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    await Firebaseinit().initFirebase();

    router = RouterComponent(
      initialRoute: 'menu',
      routes: {
        'menu': Route(() => MainMenuScreen()),
        'tictactoe': Route(() => TicTacToeBoard()),
        'settings': Route(() => SettingsScreen()),
      },
    );

    add(router);
  }
}

// Menu screen
class MainMenuScreen extends Component with HasGameReference<TicTacToeGame> {
  @override
  Future<void> onLoad() async {
    await super.onLoad();

    final background = SpriteComponent()
      ..sprite = await game.loadSprite('background.png')
      ..size = game.size
      ..position = Vector2.zero()
      ..priority = 0;
    add(background);

    add(
      TextComponent(
        text: '& ',
        position: Vector2(200, 300),
        anchor: Anchor.center,
        textRenderer: TextPaint(
          style: const TextStyle(
            fontSize: 70,
            color: Color.fromARGB(255, 255, 255, 255),
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );

    final xSprite = await game.loadSprite('X.png');
    add(
      _IconButton(
        sprite: xSprite,
        position: Vector2(120, 300),
        size: Vector2(100, 100),
        onPressed: () {},
      ),
    );

    final oSprite = await game.loadSprite('O.png');
    add(
      _IconButton(
        sprite: oSprite,
        position: Vector2(280, 300),
        size: Vector2(100, 100),
        onPressed: () {},
      ),
    );

    final playSprite = await game.loadSprite('play.png');
    final playButton = _IconButton(
      sprite: playSprite,
      position: game.size / 2 + Vector2(0, 50),
      onPressed: () => game.router.pushNamed('tictactoe'),
    );
    add(playButton);

    final vsfriendSprite = await game.loadSprite('vsfriend.png');
    final vsfriendSpriteButton = _IconButton(
      sprite: vsfriendSprite,
      position: game.size / 2 + Vector2(0, 120),
      onPressed: () => game.router.pushNamed('tictactoe'),
    );
    add(vsfriendSpriteButton);

    final vscomputerSprite = await game.loadSprite('vscomputer.png');
    final vscomputerSpriteButton = _IconButton(
      sprite: vscomputerSprite,
      position: game.size / 2 + Vector2(0, 190),
      onPressed: () => game.router.pushNamed('tictactoe'),
    );
    add(vscomputerSpriteButton);

    final competitionSprite = await game.loadSprite('competition.png');
    final competitionSpriteButton = _IconButton(
      sprite: competitionSprite,
      position: game.size / 2 + Vector2(0, 260),
      onPressed: () => game.router.pushNamed('tictactoe'),
    );
    add(competitionSpriteButton);

    final Vector2 iconSize = Vector2.all(36);

    // Notification button
    final notifSprite = await game.loadSprite('notifications.png');
    add(
      _IconButton(
        sprite: notifSprite,
        position: Vector2(350, 40),
        size: iconSize,
        onPressed: () => print('Notification tapped'),
      ),
    );
  }
}

// Flame button
class _IconButton extends SpriteComponent with TapCallbacks {
  final VoidCallback onPressed;

  _IconButton({
    required Sprite sprite,
    required Vector2 position,
    required this.onPressed,
    Vector2? size,
  }) : super(
         sprite: sprite,
         size: size ?? Vector2(200, 60),
         position: position,
         anchor: Anchor.center,
       );

  @override
  void onTapDown(TapDownEvent event) {
    FlameAudio.play('tap.wav');
    onPressed();
  }
}
