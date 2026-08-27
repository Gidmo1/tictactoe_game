import 'package:flame/components.dart';
import 'package:flutter/widgets.dart';
import 'package:tictactoe_game/components/button.dart';
import 'package:tictactoe_game/game_themes/theme.dart';

class EndMatchOverlay extends PositionComponent {
  final bool didWin;
  final bool didDraw;
  final VoidCallback onNext;
  final VoidCallback onHome;
  final VoidCallback? onRestart;
  final GameTheme theme;

  EndMatchOverlay({
    required this.didWin,
    this.didDraw = false,
    required this.onNext,
    required this.onHome,
    required this.theme,
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

    add(
      RectangleComponent(
        size: size,
        paint: Paint()..color = theme.boardBackground,
        anchor: Anchor.center,
        position: size / 2,
      ),
    );

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
}