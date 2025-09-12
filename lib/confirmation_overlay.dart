import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';

class ConfirmationOverlay extends PositionComponent {
  final String message;
  final VoidCallback onYes;
  final VoidCallback onNo;
  final double yesOffset;
  final double noOffset;

  ConfirmationOverlay({
    required this.message,
    required this.onYes,
    required this.onNo,
    this.yesOffset = 0,
    this.noOffset = 0,
  }) : super(size: Vector2(320, 180), position: Vector2(80, 200)) {
    priority = 100; // Ensure overlay is on top and blocks taps
  }

  @override
  Future<void> onLoad() async {
    // Get game reference from parent
    final gameRef = findGame() as FlameGame?;
    final overlaySprite = await gameRef?.loadSprite('confirmation_overlay.png');
    if (overlaySprite != null) {
      add(
        SpriteComponent(
          sprite: overlaySprite,
          size: size,
          position: Vector2.zero(),
        ),
      );
    }
    add(
      TextComponent(
        text: message,
        position: Vector2(size.x / 2, 30),
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
    add(
      _TextButton(
        label: 'Yes',
        position: Vector2(60 + yesOffset, size.y - 50),
        onPressed: onYes,
      ),
    );
    add(
      _TextButton(
        label: 'No',
        position: Vector2(size.x - 60 + noOffset, size.y - 50),
        onPressed: onNo,
      ),
    );
  }
}

class _TextButton extends PositionComponent with HasGameReference {
  final String label;
  final VoidCallback onPressed;

  _TextButton({
    required this.label,
    required Vector2 position,
    required this.onPressed,
  }) {
    this.position = position;
    size = Vector2(60, 40);
    anchor = Anchor.center;
  }

  @override
  Future<void> onLoad() async {
    add(
      TextComponent(
        text: label,
        position: Vector2(size.x / 2, size.y / 2),
        anchor: Anchor.center,
        textRenderer: TextPaint(
          style: const TextStyle(
            fontSize: 18,
            color: Colors.amber,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  @override
  void onTapDown(TapDownEvent event) {
    onPressed();
    parent?.removeFromParent(); // Always remove overlay
  }
}
