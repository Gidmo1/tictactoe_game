import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/effects.dart';
import 'package:flutter/material.dart';

class LeaderboardScreen extends Component with HasGameReference {
  @override
  Future<void> onLoad() async {
    await super.onLoad();
    final bg = SpriteComponent()
      ..sprite = await game.loadSprite('background.png')
      ..size = game.size
      ..position = Vector2.zero();
    add(bg);

    final leaderboardSprite = await game.loadSprite('leaderboard.png');
    add(
      SpriteComponent(
        sprite: leaderboardSprite,
        size: Vector2(300, 80),
        position: Vector2(game.size.x / 2 - 150, 60),
      ),
    );

    // Sample leaderboard data
    final entries = [
      {'name': 'Gidmo', 'score': 1200},
      {'name': 'Player2', 'score': 950},
      {'name': 'Player3', 'score': 800},
      {'name': 'Player4', 'score': 650},
      {'name': 'Player5', 'score': 500},
    ];

    double startY = 170;
    for (int i = 0; i < entries.length; i++) {
      add(
        TextComponent(
          text: "${i + 1}. ${entries[i]['name']}   ${entries[i]['score']}",
          position: Vector2(game.size.x / 2, startY + i * 50),
          anchor: Anchor.center,
          textRenderer: TextPaint(
            style: TextStyle(
              fontSize: 32,
              color: i == 0 ? Colors.amber : Colors.white,
              fontWeight: i == 0 ? FontWeight.bold : FontWeight.normal,
              shadows: [
                Shadow(
                  blurRadius: 4,
                  color: Colors.black,
                  offset: Offset(0, 2),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Return button
    final returnSprite = await game.loadSprite('return.png');
    add(
      _ArcadeButton(
        sprite: returnSprite,
        position: Vector2(40, 80),
        onPressed: () {
          final flameGame = findGame();
          if (flameGame != null) {
            final router = (flameGame as dynamic).router;
            router?.pushNamed('menu');
          }
        },
        size: Vector2(60, 60),
      ),
    );
  }
}

class _ArcadeButton extends SpriteComponent with TapCallbacks {
  final VoidCallback onPressed;

  _ArcadeButton({
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
