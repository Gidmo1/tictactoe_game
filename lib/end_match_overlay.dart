import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/effects.dart';
import 'package:flame_audio/flame_audio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:tictactoe_game/settings_screen.dart';

class EndMatchOverlay extends PositionComponent {
  // Whether the player won, lost, or drew.
  final bool didWin;
  final bool didDraw;
  final VoidCallback onNext;
  final VoidCallback onHome;
  final VoidCallback? onRestart;

  // showSignInPrompt prompts sign-in for guests; singleHomeButton for logged in users.
  EndMatchOverlay({
    required this.didWin,
    this.didDraw = false,
    required this.onNext,
    required this.onHome,
    this.showSignInPrompt = false,
    this.singleHomeButton = false,
    this.overrideMessage,
    this.onRestart,
  }) : super(size: Vector2(320, 220), anchor: Anchor.center, priority: 100);

  final bool showSignInPrompt;
  final bool singleHomeButton;
  final String? overrideMessage;

  @override
  Future<void> onLoad() async {
    debugPrint('>>> EndMatchOverlay.onLoad() called');
    final gameRef = findGame();
    if (gameRef != null) {
      position = Vector2(gameRef.size.x / 2, gameRef.size.y / 2);
      debugPrint(
        '>>> EndMatchOverlay positioned at $position, gameSize=${gameRef.size}',
      );
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
      // fallback rectangle
      add(
        RectangleComponent(
          size: size,
          paint: Paint()..color = const Color(0xCC000000),
          anchor: Anchor.center,
          position: size / 2,
        ),
      );
    }

    // Message text
    final defaultBig = didDraw
        ? 'You did your best'
        : (didWin ? 'You won!!' : 'Try harder next time');
    final defaultSmall = didDraw
        ? ''
        : (didWin ? 'Well played!' : 'Better luck next time');

    if (singleHomeButton) {
      // Compact centered small message
      add(
        TextComponent(
          text: overrideMessage ?? defaultSmall,
          anchor: Anchor.center,
          position: Vector2(size.x / 2, size.y / 2 - 20),
          textRenderer: TextPaint(
            style: const TextStyle(
              color: Color(0xFFFFFFFF),
              fontSize: 16,
              fontWeight: FontWeight.w600,
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
    } else {
      // Message text (big)
      final message = overrideMessage ?? defaultBig;

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

      // Small message
      add(
        TextComponent(
          text: defaultSmall,
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
    }

    // Home button
    final homeSprite = await (gameRef?.loadSprite('home.png'));
    if (homeSprite != null) {
      add(
        _OverlayButton(
          sprite: homeSprite,
          position: singleHomeButton
              ? Vector2(size.x / 2, size.y - 50)
              : Vector2(size.x / 2 - 70, size.y - 50),
          onPressed: () async {
            if (SettingsScreen.buttonSoundOn) FlameAudio.play('button.wav');
            onHome();
            removeFromParent();

            // Delay slightly to allow the end-match overlay to disappear.
            await Future.delayed(const Duration(milliseconds: 180));
          },
        ),
      );
    }

    // Next button (if won) or Restart button (if didn't win)
    if (!singleHomeButton) {
      if (didWin) {
        // Show "Next" button for winning
        final nextSprite = await (gameRef?.loadSprite('next.png'));
        if (nextSprite != null) {
          add(
            _OverlayButton(
              sprite: nextSprite,
              position: Vector2(size.x / 2 + 70, size.y - 50),
              onPressed: () async {
                if (SettingsScreen.buttonSoundOn) FlameAudio.play('button.wav');
                onNext();
                removeFromParent();

                // Delay slightly to allow the end-match overlay to disappear.
                await Future.delayed(const Duration(milliseconds: 180));
              },
            ),
          );
        }
      } else {
        // Show "Restart" button for not winning
        if (onRestart != null) {
          add(
            _RestartButton(
              imagePath: 'restart.png',
              position: Vector2(size.x / 2 + 80, size.y - 55),
              size: Vector2(70, 70),
              onPressed: () async {
                if (SettingsScreen.buttonSoundOn) FlameAudio.play('button.wav');
                onRestart!();
                removeFromParent();

                // Delay slightly to allow the end-match overlay to disappear.
                await Future.delayed(const Duration(milliseconds: 180));
              },
            ),
          );
        }
      }
    }

    // The avatar claim overlay is now shown only when the player presses
    // Home or Next (handled in the respective button handlers). This
    // avoids showing the picker under the end-match overlay.
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

  void onTapDown(TapDownEvent event) {
    debugPrint('>>> _OverlayButton.onTapDown called');
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
    debugPrint('>>> _OverlayButton calling onPressed after 110ms');
    Future.delayed(const Duration(milliseconds: 110), () => onPressed());
  }
}

// Specialized restart button that exposes a configurable size.
class _RestartButton extends SpriteComponent with TapCallbacks {
  final VoidCallback onPressed;
  final String imagePath;

  _RestartButton({
    required this.imagePath,
    required Vector2 position,
    required Vector2 size,
    required this.onPressed,
  }) : super(size: size, position: position, anchor: Anchor.center);

  @override
  Future<void> onLoad() async {
    sprite =
        await (findGame()?.loadSprite(imagePath) ?? Sprite.load(imagePath));
  }

  @override
  void onTapDown(TapDownEvent event) {
    if (SettingsScreen.buttonSoundOn) FlameAudio.play('button.wav');
    // Slight press animation
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
    Future.delayed(const Duration(milliseconds: 120), onPressed);
  }
}
