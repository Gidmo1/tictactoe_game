import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flame/events.dart';
import 'package:flutter/material.dart';
import 'package:tictactoe_game/confirmation_overlay.dart';

class PlayScreen extends Component with HasGameReference {
  @override
  Future<void> onLoad() async {
    await super.onLoad();
    // Background
    final bg = SpriteComponent()
      ..sprite = await game.loadSprite('background.png')
      ..size = game.size
      ..position = Vector2.zero();
    add(bg);

    // Title
    add(
      TextComponent(
        text: 'Play Online',
        position: Vector2(game.size.x / 2, 60),
        anchor: Anchor.center,
        textRenderer: TextPaint(
          style: const TextStyle(
            fontSize: 32,
            color: Colors.greenAccent,
            fontWeight: FontWeight.bold,
            shadows: [
              Shadow(blurRadius: 8, color: Colors.black, offset: Offset(0, 2)),
            ],
          ),
        ),
      ),
    );

    // League leaderboard panel (left)
    add(
      TextComponent(
        text: 'League Leaderboard',
        position: Vector2(80, 140),
        anchor: Anchor.topLeft,
        textRenderer: TextPaint(
          style: const TextStyle(
            fontSize: 22,
            color: Colors.amber,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
    // Example league leaderboard entries
    final leagueEntries = [
      {'rank': 1, 'name': 'PlayerA', 'points': 1200},
      {'rank': 2, 'name': 'PlayerB', 'points': 1100},
      {'rank': 3, 'name': 'PlayerC', 'points': 950},
    ];
    for (int i = 0; i < leagueEntries.length; i++) {
      add(
        TextComponent(
          text:
              "${leagueEntries[i]['rank']}. ${leagueEntries[i]['name']} - ${leagueEntries[i]['points']} pts",
          position: Vector2(80, 180 + i * 36),
          anchor: Anchor.topLeft,
          textRenderer: TextPaint(
            style: TextStyle(
              fontSize: 18,
              color: i == 0 ? Colors.amber : Colors.white,
            ),
          ),
        ),
      );
    }

    // Stats panel (right)
    add(
      TextComponent(
        text: 'Your Stats',
        position: Vector2(game.size.x - 80, 140),
        anchor: Anchor.topRight,
        textRenderer: TextPaint(
          style: const TextStyle(
            fontSize: 22,
            color: Colors.lightBlueAccent,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
    // Example stats
    final stats = [
      {'label': 'Wins', 'value': 25},
      {'label': 'Losses', 'value': 10},
      {'label': 'Draws', 'value': 5},
      {'label': 'League Position', 'value': 2},
    ];
    for (int i = 0; i < stats.length; i++) {
      add(
        TextComponent(
          text: "${stats[i]['label']}: ${stats[i]['value']}",
          position: Vector2(game.size.x - 80, 180 + i * 32),
          anchor: Anchor.topRight,
          textRenderer: TextPaint(
            style: const TextStyle(fontSize: 16, color: Colors.white),
          ),
        ),
      );
    }

    // Play button (center bottom)
    final playSprite = await game.loadSprite('play.png');
    add(
      SpriteComponent(
        sprite: playSprite,
        size: Vector2(120, 120),
        position: Vector2(game.size.x / 2, game.size.y - 100),
        anchor: Anchor.center,
      ),
    );
    // TODO: Implement matchmaking logic for play button

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
                removeWhere((c) => c is ConfirmationOverlay);
                final flameGame = findGame();
                if (flameGame != null) {
                  final router = (flameGame as dynamic).router;
                  router?.pop();
                }
              },
              onNo: () {
                removeWhere((c) => c is ConfirmationOverlay);
              },
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
