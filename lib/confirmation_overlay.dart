import 'package:flame/components.dart';
import 'package:flutter/widgets.dart';
import 'package:tictactoe_game/components/button.dart';
import 'package:tictactoe_game/game_themes/theme.dart';

class ConfirmationOverlay extends PositionComponent {
  final VoidCallback onYes;
  final VoidCallback onNo;
  final GameTheme theme;

  ConfirmationOverlay({
    required this.onYes,
    required this.onNo,
    required this.theme,
  }) : super(
          size: Vector2(320, 180),
          anchor: Anchor.center,
          priority: 100,
          position: Vector2(160, 100),
        );

  @override
  Future<void> onLoad() async {
    final gameRef = findGame();
    if (gameRef != null) {
      position = Vector2(gameRef.size.x / 2, gameRef.size.y / 2);
    }

    add(
      RectangleComponent(
        size: size,
        paint: Paint()..color = theme.boardBackground,
        anchor: Anchor.center,
        position: size / 2,
      ),
    );

    add(
      TextComponent(
        text: "Are you sure that you want to leave this mode? \n               You will lose the current game.",
        anchor: Anchor.topCenter,
        position: Vector2(size.x / 2, 30),
        textRenderer: TextPaint(
          style: TextStyle(
            color: theme.contrastColor,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );

    add(
      ButtonComponent(
        label: 'YES',
        position: Vector2(size.x / 2 - 80, size.y - 50),
        size: Vector2(100, 40),
        theme: theme,
        onPressed: () {
          onYes();
          removeFromParent();
        },
      ),
    );

    add(
      ButtonComponent(
        label: 'NO',
        position: Vector2(size.x / 2 + 80, size.y - 50),
        size: Vector2(100, 40),
        theme: theme,
        onPressed: () {
          onNo();
          removeFromParent();
        },
      ),
    );
  }
}