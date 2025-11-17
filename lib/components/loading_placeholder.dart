import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flutter/material.dart';

/// A small reusable Flame component that shows an immediate placeholder
/// background and a centered rotating spinner while a screen is loading.
class LoadingPlaceholder extends PositionComponent {
  /// Simple placeholder that shows `background.png` (if available) and a
  /// centered rotating `loading.png` sprite. Intentionally avoids drawing
  /// rectangle shapes so visuals come strictly from your assets.
  LoadingPlaceholder({required Vector2 size})
    : super(
        size: size,
        position: Vector2.zero(),
        anchor: Anchor.topLeft,
        priority: 10000,
      );

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    // Try to load background and loader sprites, but fall back
    // to avoid showing a blank screen if assets are missing.s
    try {
      final gameRef = findGame();
      if (gameRef != null) {
        Sprite? bgSprite;
        try {
          bgSprite = await gameRef.loadSprite('background.png');
        } catch (_) {
          bgSprite = null;
        }
        if (bgSprite != null) {
          add(
            SpriteComponent(
              sprite: bgSprite,
              size: size,
              position: Vector2.zero(),
              anchor: Anchor.topLeft,
            ),
          );
        }

        // Now try to load the rotating loader sprite
        try {
          final loader = await gameRef.loadSprite('loading.png');
          final imgSize = Vector2(120, 120);
          final sc = SpriteComponent(
            sprite: loader,
            size: imgSize,
            position: size / 2 - imgSize / 2,
            anchor: Anchor.topLeft,
          );
          sc.add(
            RotateEffect.by(
              6.28,
              EffectController(
                duration: 1.2,
                infinite: true,
                curve: Curves.linear,
              ),
            ),
          );
          add(sc);
          return;
        } catch (_) {
          // fall through to text fallback below
        }
      }
    } catch (_) {
      // ignore and fall back
    }

    // Last-resort fallback: show a textual loading indicator so the screen
    // is never completely empty. This avoids drawing shapes while remaining
    // readable.
    add(
      TextComponent(
        text: 'Loading...',
        position: size / 2,
        anchor: Anchor.center,
        textRenderer: TextPaint(
          style: const TextStyle(color: Colors.white, fontSize: 18),
        ),
      ),
    );
  }
}
