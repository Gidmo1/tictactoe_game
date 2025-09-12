import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/effects.dart';
import 'package:flame/sprite.dart';
import 'package:flutter/material.dart';

class CurrencyBar extends Component with HasGameReference {
  final int coins;
  final int xp;
  CurrencyBar({required this.coins, required this.xp});

  @override
  Future<void> onLoad() async {
    final atlas = await game.loadSprite('resources_sprites.png');
    // Each sprite is 64x64
    final coinSprite = Sprite(
      atlas.image,
      srcPosition: Vector2(128, 0),
      srcSize: Vector2(64, 64),
    ); // Row 1, col 3
    final xpSprite = Sprite(
      atlas.image,
      srcPosition: Vector2(0, 64),
      srcSize: Vector2(64, 64),
    ); // Row 2, col 1 (star)
    final plusSprite = Sprite(
      atlas.image,
      srcPosition: Vector2(320, 128),
      srcSize: Vector2(64, 64),
    ); // Row 3, col 6

    add(
      RectangleComponent(
        position: Vector2(10, 10),
        size: Vector2(game.size.x - 20, 40),
        paint: Paint()..color = Colors.black.withOpacity(0.5),
        priority: 10,
      ),
    );
    add(
      SpriteComponent(
        sprite: coinSprite,
        size: Vector2(32, 32),
        position: Vector2(20, 14),
        priority: 11,
      ),
    );
    add(
      TextComponent(
        text: coins.toString(),
        position: Vector2(60, 30),
        anchor: Anchor.centerLeft,
        textRenderer: TextPaint(
          style: TextStyle(
            fontSize: 22,
            color: Colors.amber,
            fontWeight: FontWeight.bold,
          ),
        ),
        priority: 11,
      ),
    );
    add(
      ArcadeButton(
        sprite: plusSprite,
        position: Vector2(120, 30),
        size: Vector2(28, 28),
        onPressed: () {
          // TODO: Open shop screen for coins
        },
      ),
    );
    add(
      SpriteComponent(
        sprite: xpSprite,
        size: Vector2(32, 32),
        position: Vector2(170, 14),
        priority: 11,
      ),
    );
    add(
      TextComponent(
        text: xp.toString(),
        position: Vector2(210, 30),
        anchor: Anchor.centerLeft,
        textRenderer: TextPaint(
          style: TextStyle(
            fontSize: 22,
            color: Colors.lightBlueAccent,
            fontWeight: FontWeight.bold,
          ),
        ),
        priority: 11,
      ),
    );
    add(
      ArcadeButton(
        sprite: plusSprite,
        position: Vector2(270, 30),
        size: Vector2(28, 28),
        onPressed: () {
          // TODO: Open shop screen for XP
        },
      ),
    );
  }
}

class ArcadeButton extends SpriteComponent with TapCallbacks {
  final VoidCallback onPressed;

  ArcadeButton({
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
