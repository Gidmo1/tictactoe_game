import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';

class ConfirmationOverlay extends PositionComponent {
  final String message;
  final VoidCallback onYes;
  final VoidCallback onNo;

  ConfirmationOverlay({
    required this.message,
    required this.onYes,
    required this.onNo,
  }) : super(size: Vector2(320, 180), anchor: Anchor.center, priority: 100);

  @override
  Future<void> onLoad() async {
    final gameRef = findGame() as FlameGame?;
    if (gameRef != null) {
      // Center the overlay
      position = Vector2(gameRef.size.x / 2, gameRef.size.y / 2);
    }

    // Background (can replace with sprite if you want)
    add(
      RectangleComponent(
        size: size,
        paint: Paint()..color = Colors.black.withOpacity(0.8),
        anchor: Anchor.topLeft,
      ),
    );

    // Message
    add(
      TextComponent(
        text: message,
        position: Vector2(size.x / 2, 40),
        anchor: Anchor.center,
        textRenderer: TextPaint(
          style: const TextStyle(
            fontSize: 20,
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );

    // Yes button
    add(
      _OverlayButton(
        label: "Yes",
        position: Vector2(size.x / 2 - 60, size.y - 50),
        onPressed: () {
          onYes();
          removeFromParent();
        },
      ),
    );

    // No button
    add(
      _OverlayButton(
        label: "No",
        position: Vector2(size.x / 2 + 60, size.y - 50),
        onPressed: () {
          onNo();
          removeFromParent();
        },
      ),
    );
  }
}

class _OverlayButton extends PositionComponent with TapCallbacks {
  final String label;
  final VoidCallback onPressed;

  _OverlayButton({
    required this.label,
    required Vector2 position,
    required this.onPressed,
  }) {
    this.position = position;
    size = Vector2(80, 40);
    anchor = Anchor.center;
  }

  @override
  Future<void> onLoad() async {
    // Button background
    add(
      RectangleComponent(
        size: size,
        paint: Paint()..color = const Color.fromARGB(255, 200, 121, 3),
        anchor: Anchor.topLeft,
      ),
    );

    // Button text
    add(
      TextComponent(
        text: label,
        position: Vector2(size.x / 2, size.y / 2),
        anchor: Anchor.center,
        textRenderer: TextPaint(
          style: const TextStyle(
            fontSize: 18,
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  @override
  void onTapDown(TapDownEvent event) {
    onPressed();
    removeFromParent();
  }
}
