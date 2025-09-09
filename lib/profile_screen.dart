import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:tictactoe_game/tictactoe.dart';

class ProfileScreen extends Component with HasGameReference<TicTacToeGame> {
  final String username;
  final String? photoUrl;

  ProfileScreen({required this.username, this.photoUrl});

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    final background = SpriteComponent()
      ..sprite = await Sprite.load('background.png')
      ..size = game.size
      ..position = Vector2.zero()
      ..priority = 0;
    add(background);

    add(
      TextComponent(
        text: 'Profile',
        position: Vector2(game.size.x / 2, 80),
        anchor: Anchor.center,
        textRenderer: TextPaint(
          style: const TextStyle(
            fontSize: 40,
            color: Colors.white,
            fontWeight: FontWeight.bold,
            shadows: [
              Shadow(color: Colors.black, blurRadius: 8, offset: Offset(0, 2)),
            ],
          ),
        ),
      ),
    );

    if (photoUrl != null && photoUrl!.isNotEmpty) {
      add(
        SpriteComponent()
          ..sprite = await Sprite.load(photoUrl!)
          ..size = Vector2(100, 100)
          ..position = Vector2(game.size.x / 2, 160)
          ..anchor = Anchor.center,
      );
    }

    add(
      TextComponent(
        text: 'Username: $username',
        position: Vector2(game.size.x / 2, 220),
        anchor: Anchor.center,
        textRenderer: TextPaint(
          style: const TextStyle(
            fontSize: 24,
            color: Colors.white,
            fontWeight: FontWeight.bold,
            shadows: [
              Shadow(color: Colors.black, blurRadius: 8, offset: Offset(0, 2)),
            ],
          ),
        ),
      ),
    );
  }
}
