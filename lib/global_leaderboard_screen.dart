import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flame/events.dart';
import 'package:flutter/material.dart';
import 'package:tictactoe_game/confirmation_overlay.dart';

class GlobalLeaderboardScreen extends Component with HasGameReference {
  @override
  Future<void> onLoad() async {
    await super.onLoad();
    // Show loading bar while fetching leaderboard
    for (int i = 1; i <= 4; i++) {
      await Future.delayed(const Duration(milliseconds: 60));
    }

    final bg = SpriteComponent()
      ..sprite = await game.loadSprite('background.png')
      ..size = game.size
      ..position = Vector2.zero();
    add(bg);

    add(
      TextComponent(
        text: 'Global Leaderboard',
        position: Vector2(game.size.x / 2, 80),
        anchor: Anchor.center,
        textRenderer: TextPaint(
          style: const TextStyle(
            fontSize: 32,
            color: Colors.amber,
            fontWeight: FontWeight.bold,
            shadows: [
              Shadow(blurRadius: 8, color: Colors.black, offset: Offset(0, 2)),
            ],
          ),
        ),
      ),
    );

    try {
      // Fetch leaderboard from Firestore
      final snapshot = await FirebaseFirestore.instance
          .collection('global_leaderboard')
          .orderBy('score', descending: true)
          .limit(20)
          .get();
      // Update loading bar to near complete
      final entries = snapshot.docs.map((doc) => doc.data()).toList();
      double startY = 140;
      for (int i = 0; i < entries.length; i++) {
        add(
          TextComponent(
            text: "${i + 1}. ${entries[i]['name']} - ${entries[i]['score']}",
            position: Vector2(game.size.x / 2, startY + i * 40),
            anchor: Anchor.topCenter,
            textRenderer: TextPaint(
              style: TextStyle(
                fontSize: 22,
                color: i == 0 ? Colors.amber : Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        );
      }
    } catch (e) {
      add(
        TextComponent(
          text:
              'Unable to load leaderboard. Please check your internet connection.',
          position: Vector2(game.size.x / 2, game.size.y / 2),
          anchor: Anchor.center,
          textRenderer: TextPaint(
            style: const TextStyle(
              fontSize: 24,
              color: Colors.redAccent,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      );
    }
    // Remove loading screen after leaderboard is ready

    // Return button
    final returnSprite = await game.loadSprite('return.png');
    add(
      _ReturnButton(
        sprite: returnSprite,
        position: Vector2(60, 60),
        onPressed: () {
          add(
            ConfirmationOverlay(
              message: 'Return to menu?',
              onYes: () {
                final flameGame = findGame();
                if (flameGame != null) {
                  final router = (flameGame as dynamic).router;
                  router?.pop();
                }
              },
              onNo: () {},
            ),
          );
        },
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
  }) : super(
         sprite: sprite,
         position: position,
         size: Vector2(50, 50),
         anchor: Anchor.center,
       );

  @override
  void onTapDown(TapDownEvent event) {
    add(ScaleEffect.to(Vector2(0.9, 0.9), EffectController(duration: 0.05)));
    Future.delayed(const Duration(milliseconds: 120), onPressed);
  }
}
