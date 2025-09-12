import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flame/events.dart';
import 'package:flutter/material.dart';
import 'package:tictactoe_game/confirmation_overlay.dart';

class LeagueLeaderboardScreen extends Component with HasGameReference {
  @override
  Future<void> onLoad() async {
    await super.onLoad();
    final bg = SpriteComponent()
      ..sprite = await game.loadSprite('background.png')
      ..size = game.size
      ..position = Vector2.zero();
    add(bg);

    // Leaderboard header image (smaller size)
    final headerSprite = await game.loadSprite('leaderboard_header.png');
    add(
      SpriteComponent(
        sprite: headerSprite,
        size: Vector2(260, 60),
        position: Vector2(game.size.x / 2 - 130, 40),
        anchor: Anchor.topLeft,
      ),
    );

    // Fetch current league leaderboard from Firestore
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('league_leaderboard')
          .orderBy('points', descending: true)
          .limit(20)
          .get();
      final entries = snapshot.docs.map((doc) => doc.data()).toList();
      double startY = 140;
      for (int i = 0; i < entries.length; i++) {
        add(
          TextComponent(
            text:
                "${i + 1}. ${entries[i]['name']} - ${entries[i]['points']} pts",
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

      // Show eFootball-style stats for current user
      // Example stats, replace with real user data
      final stats = [
        {'label': 'Wins', 'value': 25},
        {'label': 'Losses', 'value': 10},
        {'label': 'Draws', 'value': 5},
        {'label': 'League Position', 'value': 2},
        {'label': 'Points', 'value': 1200},
      ];
      double statsStartY = startY + entries.length * 40 + 40;
      add(
        TextComponent(
          text: 'Your Stats',
          position: Vector2(game.size.x / 2, statsStartY),
          anchor: Anchor.topCenter,
          textRenderer: TextPaint(
            style: const TextStyle(
              fontSize: 22,
              color: Colors.lightBlueAccent,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      );
      for (int i = 0; i < stats.length; i++) {
        add(
          TextComponent(
            text: "${stats[i]['label']}: ${stats[i]['value']}",
            position: Vector2(game.size.x / 2, statsStartY + 32 + i * 28),
            anchor: Anchor.topCenter,
            textRenderer: TextPaint(
              style: const TextStyle(fontSize: 16, color: Colors.white),
            ),
          ),
        );
      }
    } catch (e) {
      add(
        TextComponent(
          text:
              'Unable to load league leaderboard. Please check your internet connection.',
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

    // Return button (move left)
    final returnSprite = await game.loadSprite('return.png');
    add(
      _ReturnButton(
        sprite: returnSprite,
        position: Vector2(25, 60),
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
              yesOffset: 30,
              noOffset: -30,
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
