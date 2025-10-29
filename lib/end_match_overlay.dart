import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/effects.dart';
import 'package:flame_audio/flame_audio.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tictactoe_game/settings_screen.dart';
import 'components/auth_gate_component.dart';

class EndMatchOverlay extends PositionComponent {
  // Whether the player won, lost, or drew.
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

    // Small message
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

    // Show the Flame-native AuthGateComponent for first-time guest players.
    try {
      final authUser = fb.FirebaseAuth.instance.currentUser;
      final prefs = await SharedPreferences.getInstance();
      final seenSignInPrompt = prefs.getBool('seen_signin_prompt') ?? false;

      if (authUser == null && !seenSignInPrompt) {
        await prefs.setBool('seen_signin_prompt', true);
        final flameGame = findGame();
        if (flameGame != null) {
          final gate = AuthGateComponent(
            onSignedIn: () async {
              // Post sign-in handled inside the component (score sync);
            },
            nonDismissible: false,
          );
          gate.priority = 10060;
          flameGame.add(gate);
        }
      }
    } catch (e) {
      debugPrint('Sign-in prompt logic failed: $e');
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
         size: size ?? Vector2(64, 64),
         anchor: Anchor.center,
       );

  void onTapDown(TapDownEvent event) {
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
    Future.delayed(const Duration(milliseconds: 110), () => onPressed());
  }
}

// _SmallOverlayButton removed — replaced by AuthGateComponent usage for sign-in prompts.
