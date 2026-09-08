import 'dart:math';

import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flutter/widgets.dart';
import 'package:tictactoe_game/components/button.dart';
import 'package:tictactoe_game/components/ornate_overlay_panel.dart';
import 'package:tictactoe_game/game_themes/theme.dart';

class EndMatchOverlay extends PositionComponent {
  final bool didWin;
  final bool didDraw;
  final VoidCallback onNext;
  final VoidCallback onHome;
  final VoidCallback? onRestart;
  final GameTheme theme;
  final String? scoreline;
  final String? scoreXText;
  final String? scoreOText;
  final Color? scoreXColor;
  final Color? scoreOColor;
  bool _confettiRunning = false;
  final Random _random = Random();
  final List<Component> _confettiPieces = [];

  EndMatchOverlay({
    required this.didWin,
    this.didDraw = false,
    required this.onNext,
    required this.onHome,
    required this.theme,
    this.scoreline,
    this.scoreXText,
    this.scoreOText,
    this.scoreXColor,
    this.scoreOColor,
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
    final gameRef = findGame();
    if (gameRef != null) {
      position = Vector2(gameRef.size.x / 2, gameRef.size.y / 2);
    }

    if (didWin && !didDraw) {
      _startConfetti();
    }

    add(OrnateOverlayPanel(size: size, theme: theme));

    final defaultBig = didDraw
        ? 'You did your best'
        : (didWin ? 'You won!!' : 'Try harder next time');
    final defaultSmall = didDraw
        ? ''
        : (didWin ? 'Well played!' : 'Better luck next time');

    final textStyle = TextStyle(
      color: theme.contrastColor,
      fontSize: 22,
      fontWeight: FontWeight.bold,
    );
    final smallTextStyle = TextStyle(
      color: theme.contrastColor,
      fontSize: 14,
      fontWeight: FontWeight.w600,
    );

    if (singleHomeButton) {
      add(
        TextComponent(
          text: overrideMessage ?? defaultSmall,
          anchor: Anchor.center,
          position: Vector2(size.x / 2, size.y / 2 - 20),
          textRenderer: TextPaint(style: smallTextStyle),
        ),
      );
      if (scoreXText != null && scoreOText != null) {
        add(
          TextComponent(
            text: scoreline ?? '0  -  0',
            anchor: Anchor.center,
            position: Vector2(size.x / 2, size.y / 2 + 30),
            textRenderer: TextPaint(
              style: smallTextStyle.copyWith(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        );
        add(
          TextComponent(
            text: scoreXText!,
            anchor: Anchor.centerRight,
            position: Vector2(size.x / 2 - 36, size.y / 2 + 6),
            textRenderer: TextPaint(
              style: smallTextStyle.copyWith(
                color: scoreXColor ?? smallTextStyle.color,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        );
        add(
          TextComponent(
            text: scoreOText!,
            anchor: Anchor.centerLeft,
            position: Vector2(size.x / 2 + 36, size.y / 2 + 6),
            textRenderer: TextPaint(
              style: smallTextStyle.copyWith(
                color: scoreOColor ?? smallTextStyle.color,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        );
      } else if (scoreline != null) {
        add(
          TextComponent(
            text: scoreline!,
            anchor: Anchor.center,
            position: Vector2(size.x / 2, size.y / 2 + 16),
            textRenderer: TextPaint(
              style: smallTextStyle.copyWith(
                fontSize: 16,
                height: 1.5,
                letterSpacing: 1.2,
              ),
            ),
          ),
        );
      }
    } else {
      add(
        TextComponent(
          text: overrideMessage ?? defaultBig,
          anchor: Anchor.topCenter,
          position: Vector2(size.x / 2, 26),
          textRenderer: TextPaint(style: textStyle),
        ),
      );

      if (defaultSmall.isNotEmpty) {
        add(
          TextComponent(
            text: defaultSmall,
            anchor: Anchor.topCenter,
            position: Vector2(size.x / 2, 62),
            textRenderer: TextPaint(style: smallTextStyle),
          ),
        );
      }
      if (scoreXText != null && scoreOText != null) {
        add(
          TextComponent(
            text: scoreline ?? '0  -  0',
            anchor: Anchor.center,
            position: Vector2(size.x / 2, 122),
            textRenderer: TextPaint(
              style: smallTextStyle.copyWith(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        );
        add(
          TextComponent(
            text: scoreXText!,
            anchor: Anchor.centerRight,
            position: Vector2(size.x / 2 - 36, 94),
            textRenderer: TextPaint(
              style: smallTextStyle.copyWith(
                color: scoreXColor ?? smallTextStyle.color,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        );
        add(
          TextComponent(
            text: scoreOText!,
            anchor: Anchor.centerLeft,
            position: Vector2(size.x / 2 + 36, 94),
            textRenderer: TextPaint(
              style: smallTextStyle.copyWith(
                color: scoreOColor ?? smallTextStyle.color,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        );
      } else if (scoreline != null) {
        add(
          TextComponent(
            text: scoreline!,
            anchor: Anchor.topCenter,
            position: Vector2(size.x / 2, 98),
            textRenderer: TextPaint(
              style: smallTextStyle.copyWith(
                fontSize: 16,
                height: 1.5,
                letterSpacing: 1.2,
              ),
            ),
          ),
        );
      }
    }

    final btnSize = Vector2(100, 40);
    add(
      ButtonComponent(
        label: 'HOME',
        position: singleHomeButton
            ? Vector2(size.x / 2, size.y - 50)
            : Vector2(size.x / 2 - 70, size.y - 50),
        size: btnSize,
        theme: theme,
        onPressed: () {
          onHome();
          removeFromParent();
        },
      ),
    );

    if (!singleHomeButton) {
      if (didWin) {
        add(
          ButtonComponent(
            label: 'NEXT',
            position: Vector2(size.x / 2 + 70, size.y - 50),
            size: btnSize,
            theme: theme,
            onPressed: () {
              onNext();
              removeFromParent();
            },
          ),
        );
      } else if (onRestart != null) {
        add(
          ButtonComponent(
            label: 'RESTART',
            position: Vector2(size.x / 2 + 80, size.y - 55),
            size: btnSize,
            theme: theme,
            onPressed: () {
              onRestart!();
              removeFromParent();
            },
          ),
        );
      }
    }
  }

  void _startConfetti() {
    if (_confettiRunning) return;
    _confettiRunning = true;

    void spawnConfettiPiece() {
      if (!_confettiRunning || !isMounted) return;

      final confettiSize = 4 + _random.nextDouble() * 6;
      final paint = Paint()
        ..color = Color.fromARGB(
          255,
          _random.nextInt(256),
          _random.nextInt(256),
          _random.nextInt(256),
        );

      final confetti = RectangleComponent(
        size: Vector2(confettiSize, confettiSize * 1.5),
        paint: paint,
        position: Vector2(_random.nextDouble() * size.x, -10),
        anchor: Anchor.center,
      );

      _confettiPieces.add(confetti);
      add(confetti);

      final fallDuration = 1.5 + _random.nextDouble() * 1.5;
      confetti.add(
        MoveEffect.to(
          Vector2(confetti.x, size.y + 50),
          EffectController(duration: fallDuration, curve: Curves.linear),
          onComplete: () {
            confetti.removeFromParent();
            _confettiPieces.remove(confetti);
          },
        ),
      );

      confetti.add(
        RotateEffect.by(
          _random.nextDouble() * pi * 4,
          EffectController(duration: fallDuration, curve: Curves.linear),
        ),
      );

      Future.delayed(const Duration(milliseconds: 15), spawnConfettiPiece);
    }

    spawnConfettiPiece();
    Future.delayed(
      const Duration(milliseconds: 2400),
      () => _confettiRunning = false,
    );
  }
}
