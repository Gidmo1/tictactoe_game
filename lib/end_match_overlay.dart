import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/effects.dart';
// package:flame/game.dart import not required; components already provides types used here
import 'package:flame_audio/flame_audio.dart';
import 'package:flutter/widgets.dart';
import 'package:tictactoe_game/settings_screen.dart';

class EndMatchOverlay extends PositionComponent {
  /// whether the human won (true), lost (false) or draw (both equal handled by didDraw)
  final bool didWin;
  final bool didDraw;
  final VoidCallback onNext;
  final VoidCallback onHome;

  EndMatchOverlay({
    required this.didWin,
    this.didDraw = false,
    required this.onNext,
    required this.onHome,
  }) : super(size: Vector2(320, 220), anchor: Anchor.center, priority: 100);

  @override
  Future<void> onLoad() async {
    final gameRef = findGame();
    if (gameRef != null) {
      position = Vector2(gameRef.size.x / 2, gameRef.size.y / 2);
    }

    // background sprite
    final bgSprite = await (gameRef?.loadSprite('confirmation_overlay.png'));
    if (bgSprite != null) {
      add(
        SpriteComponent(
          sprite: bgSprite,
          size: size,
          anchor: Anchor.center,
          position: size / 2,
        ),
      );
    } else {
      // fallback translucent rectangle
      add(
        RectangleComponent(
          size: size,
          paint: Paint()..color = const Color(0xCC000000),
          anchor: Anchor.center,
          position: size / 2,
        ),
      );
    }

    // Message text (big)
    final message = didDraw
        ? 'You did your best'
        : (didWin ? 'You won!!' : 'Try harder next time');

    add(
      TextComponent(
        text: message,
        anchor: Anchor.topCenter,
        position: Vector2(size.x / 2, 26),
        textRenderer: TextPaint(
          style: const TextStyle(
            color: Color(0xFFFFFFFF),
            fontSize: 22,
            fontWeight: FontWeight.bold,
            shadows: [
              Shadow(
                blurRadius: 2,
                color: Color(0xFF000000),
                offset: Offset(0, 1),
              ),
            ],
          ),
        ),
      ),
    );

    // Optional small details text
    add(
      TextComponent(
        text: didDraw
            ? ''
            : (didWin ? 'Well played!' : 'Better luck next time'),
        anchor: Anchor.topCenter,
        position: Vector2(size.x / 2, 62),
        textRenderer: TextPaint(
          style: const TextStyle(
            color: Color(0xFFD2B48C),
            fontSize: 14,
            fontWeight: FontWeight.w600,
            shadows: [
              Shadow(
                blurRadius: 1,
                color: Color(0xFF000000),
                offset: Offset(0, 1),
              ),
            ],
          ),
        ),
      ),
    );

    // Home button
    final homeSprite = await (gameRef?.loadSprite('home.png'));
    if (homeSprite != null) {
      add(
        _OverlayButton(
          sprite: homeSprite,
          position: Vector2(size.x / 2 - 70, size.y - 50),
          onPressed: () {
            if (SettingsScreen.buttonSoundOn) FlameAudio.play('button.wav');
            onHome();
            removeFromParent();
          },
        ),
      );
    }

    // Next button
    final nextSprite = await (gameRef?.loadSprite('next.png'));
    if (nextSprite != null) {
      add(
        _OverlayButton(
          sprite: nextSprite,
          position: Vector2(size.x / 2 + 70, size.y - 50),
          onPressed: () {
            if (SettingsScreen.buttonSoundOn) FlameAudio.play('button.wav');
            onNext();
            removeFromParent();
          },
        ),
      );
    }
  }
}

class _OverlayButton extends SpriteComponent with TapCallbacks {
  final VoidCallback onPressed;

  _OverlayButton({
    required Sprite sprite,
    required Vector2 position,
    required this.onPressed,
    Vector2? size,
  }) : super(
         sprite: sprite,
         position: position,
         size: size ?? Vector2(120, 50),
         anchor: Anchor.center,
       );

  @override
  void onTapDown(TapDownEvent event) {
    // sound handled by caller if needed, but keep local as well for quick feedback
    if (SettingsScreen.buttonSoundOn) FlameAudio.play('button.wav');

    add(
      SequenceEffect([
        ScaleEffect.to(Vector2(0.92, 0.92), EffectController(duration: 0.05)),
        ScaleEffect.to(
          Vector2(1.06, 1.06),
          EffectController(duration: 0.09, curve: Curves.easeOut),
        ),
        ScaleEffect.to(
          Vector2(1.0, 1.0),
          EffectController(duration: 0.05, curve: Curves.easeIn),
        ),
      ]),
    );

    // slight delay so effect is visible
    Future.delayed(const Duration(milliseconds: 110), () => onPressed());
  }
}
