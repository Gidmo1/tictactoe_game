import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flame/events.dart';
import 'package:flutter/material.dart';
import 'package:tictactoe_game/confirmation_overlay.dart'; // Keep this import for confirmation overlay

class CompetitionScreen extends Component with HasGameReference {
  @override
  Future<void> onLoad() async {
    await super.onLoad();
    // Background
    final bg = SpriteComponent()
      ..sprite = await game.loadSprite('background.png')
      ..size = game.size
      ..position = Vector2.zero();
    add(bg);

    // Return Button (top left)
    final returnSprite = await game.loadSprite('return.png');
    add(
      _ArcadeButton(
        sprite: returnSprite,
        position: Vector2(40, 40),
        size: Vector2(60, 60),
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

    // Bronze Level Label
    add(
      TextComponent(
        text: 'Bronze',
        position: Vector2(game.size.x / 2, 60),
        anchor: Anchor.center,
        textRenderer: TextPaint(
          style: const TextStyle(
            fontSize: 36,
            color: Colors.brown,
            fontWeight: FontWeight.bold,
            shadows: [
              Shadow(blurRadius: 8, color: Colors.black, offset: Offset(0, 2)),
            ],
          ),
        ),
      ),
    );

    // Leaderboard title
    double leaderboardStartY = 120;
    add(
      TextComponent(
        text: 'Leaderboard:',
        position: Vector2(game.size.x / 2, leaderboardStartY),
        anchor: Anchor.topCenter,
        textRenderer: TextPaint(
          style: const TextStyle(
            fontSize: 28,
            color: Colors.amber,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );

    /*
    // Loading screen while fetching leaderboard
    bool leaderboardLoaded = false;
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('bronze_leaderboard')
          .orderBy('score', descending: true)
          .limit(10)
          .get();
      final entries = snapshot.docs.map((doc) => doc.data()).toList();
      for (int i = 0; i < entries.length; i++) {
        add(
          TextComponent(
            text:
                "${i + 1}. ${entries[i]['name']} - ${entries[i]['score']} pts",
            position: Vector2(game.size.x / 2, leaderboardStartY + 40 + i * 32),
            anchor: Anchor.topCenter,
            textRenderer: TextPaint(
              style: const TextStyle(fontSize: 22, color: Colors.white),
            ),
          ),
        );
      }
      if (entries.isEmpty) {
        add(
          TextComponent(
            text: 'No entries yet.',
            position: Vector2(game.size.x / 2, leaderboardStartY + 40),
            anchor: Anchor.topCenter,
            textRenderer: TextPaint(
              style: const TextStyle(fontSize: 22, color: Colors.white),
            ),
          ),
        );
      }
      leaderboardLoaded = true;
    } catch (e) {
      add(
        TextComponent(
          text: 'Unable to load leaderboard.',
          position: Vector2(game.size.x / 2, leaderboardStartY + 40),
          anchor: Anchor.topCenter,
          textRenderer: TextPaint(
            style: const TextStyle(fontSize: 22, color: Colors.redAccent),
          ),
        ),
      );
    }
    await Future.delayed(const Duration(milliseconds: 400));
    if (!leaderboardLoaded) {
      add(
        TextComponent(
          text: 'Leaderboard unavailable. Try again later.',
          position: Vector2(game.size.x / 2, leaderboardStartY + 100),
          anchor: Anchor.topCenter,
          textRenderer: TextPaint(
            style: const TextStyle(fontSize: 22, color: Colors.redAccent),
          ),
        ),
      );
    }
    */
    // Fetch leaderboard from Firebase (Bronze level)
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('bronze_leaderboard')
          .orderBy('score', descending: true)
          .limit(10)
          .get();
      final entries = snapshot.docs.map((doc) => doc.data()).toList();
      for (int i = 0; i < entries.length; i++) {
        add(
          TextComponent(
            text:
                "${i + 1}. ${entries[i]['name']} - ${entries[i]['score']} pts",
            position: Vector2(game.size.x / 2, leaderboardStartY + 40 + i * 32),
            anchor: Anchor.topCenter,
            textRenderer: TextPaint(
              style: const TextStyle(fontSize: 22, color: Colors.white),
            ),
          ),
        );
      }
      if (entries.isEmpty) {
        add(
          TextComponent(
            text: 'No entries yet.',
            position: Vector2(game.size.x / 2, leaderboardStartY + 40),
            anchor: Anchor.topCenter,
            textRenderer: TextPaint(
              style: const TextStyle(fontSize: 22, color: Colors.white),
            ),
          ),
        );
      }
    } catch (e) {
      add(
        TextComponent(
          text: 'Unable to load leaderboard.',
          position: Vector2(game.size.x / 2, leaderboardStartY + 40),
          anchor: Anchor.topCenter,
          textRenderer: TextPaint(
            style: const TextStyle(fontSize: 22, color: Colors.redAccent),
          ),
        ),
      );
    }

    // VS Computer Button (routes to VS AI)
    final vsComputerSprite = await game.loadSprite('play.png');
    add(
      _ArcadeButton(
        sprite: vsComputerSprite,
        position: Vector2(game.size.x / 2, leaderboardStartY + 320),
        size: Vector2(260, 70),
        onPressed: () {
          final flameGame = findGame();
          if (flameGame != null) {
            final router = (flameGame as dynamic).router;
            router?.pushNamed('vsai');
          }
        },
      ),
    );

    // Join Competition Button (bottom center)
    final joinSprite = await game.loadSprite('joinatournament.png');
    add(
      _ArcadeButton(
        sprite: joinSprite,
        position: Vector2(game.size.x / 2, game.size.y - 80),
        size: Vector2(260, 70),
        onPressed: () {
          // TODO: Implement join competition logic
        },
      ),
    );
  }
}

class _ArcadeButton extends SpriteComponent with TapCallbacks {
  final VoidCallback onPressed;

  _ArcadeButton({
    required this.onPressed,
    required Sprite sprite,
    required Vector2 position,
    Vector2? size,
  }) : super(
         sprite: sprite,
         position: position,
         size: size ?? Vector2(200, 60),
       ) {
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
    Future.delayed(Duration(milliseconds: 150), onPressed);
  }
}

// ...existing code...
