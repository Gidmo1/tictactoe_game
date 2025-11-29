import 'dart:async';
import 'dart:math';
import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flame/events.dart';
import 'package:flutter/material.dart';
import 'package:flame_audio/flame_audio.dart';
import 'package:tictactoe_game/settings_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TicTacToeCell extends PositionComponent with TapCallbacks {
  final int row, col;
  SpriteComponent? markSprite;

  TicTacToeCell({
    required this.row,
    required this.col,
    required Vector2 position,
    required Vector2 size,
  }) : super(position: position, size: size);

  void mark(String symbol) async {
    markSprite?.removeFromParent();
    final spritePath = symbol == 'X' ? 'X.png' : 'O.png';
    markSprite = SpriteComponent()
      ..sprite =
          await (findGame()?.loadSprite(spritePath) ?? Sprite.load(spritePath))
      ..size = Vector2(70, 70)
      ..anchor = Anchor.center
      ..position = size / 2;
    add(markSprite!);
  }

  @override
  void onTapDown(TapDownEvent event) {
    if (SettingsScreen.buttonSoundOn) FlameAudio.play('tap.wav');
    (parent as TicTacToeBoard).handleTap(row, col);
  }
}

class TicTacToeBoard extends Component {
  List<List<String>> board = List.generate(3, (_) => List.filled(3, ''));
  String currentPlayer = 'O';
  late TextComponent messageText;
  bool gameOver = false;

  final double cellWidth = 390 / 3;
  final double cellHeight = 321 / 3;
  final double boardX = 4;
  final double boardY = 318;

  bool confettiRunning = false;
  final Random random = Random();
  final List<Component> confettiPieces = [];

  @override
  Future<void> onLoad() async {
    final canvasSize = findGame()?.size ?? Vector2(360, 640);

    // Background
    final background = SpriteComponent()
      ..sprite =
          await (findGame()?.loadSprite('playscreen.png') ??
              Sprite.load('playscreen.png'))
      ..size = canvasSize
      ..position = Vector2.zero();
    add(background);

    // Player profile image - use chosen avatar if available
    try {
      final prefs = await SharedPreferences.getInstance();
      final chosen = prefs.getString('chosen_avatar');
      Sprite? sprite;
      if (chosen != null && chosen.isNotEmpty) {
        try {
          sprite =
              await (findGame()?.loadSprite('$chosen.png') ??
                  Sprite.load('$chosen.png'));
        } catch (_) {
          sprite = null;
        }
      }
      if (sprite != null) {
        final profile = SpriteComponent()
          ..sprite = sprite
          ..size = Vector2(56, 56)
          ..position = Vector2(20, 40)
          ..anchor = Anchor.topLeft;
        add(profile);
      }
    } catch (e) {
      // If asset missing or fails to load, ignore silently
      print('Failed to load profile image: $e');
    }

    // Message text
    messageText = TextComponent(
      text: "Player $currentPlayer's turn",
      position: Vector2(canvasSize.x / 2, boardY - 80),
      anchor: Anchor.center,
      textRenderer: TextPaint(
        style: const TextStyle(
          fontSize: 24,
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
    add(messageText);

    // Buttons
    add(
      _PressdownButton(
        imagePath: 'return.png',
        position: Vector2(40, 180),
        size: Vector2(60, 60),
        onPressed: () {
          final flameGame = findGame();
          if (flameGame != null) {
            final router = (flameGame as dynamic).router;
            router?.pushNamed('menu');
          }
        },
      ),
    );

    add(
      _PressdownButton(
        imagePath: 'settings.png',
        position: Vector2(canvasSize.x - 50, 70),
        size: Vector2(40, 40),
        onPressed: () {
          final flameGame = findGame();
          if (flameGame != null) {
            final router = (flameGame as dynamic).router;
            router?.pushNamed('settings');
          }
        },
      ),
    );

    add(
      _PressdownButton(
        imagePath: 'restart.png',
        position: Vector2(canvasSize.x / 2, canvasSize.y - 70),
        size: Vector2(80, 80),
        onPressed: restartGame,
      ),
    );

    // Board cells
    for (int row = 0; row < 3; row++) {
      for (int col = 0; col < 3; col++) {
        add(
          TicTacToeCell(
            row: row,
            col: col,
            position: Vector2(
              boardX + col * cellWidth,
              boardY + row * cellHeight,
            ),
            size: Vector2(cellWidth, cellHeight),
          ),
        );
      }
    }
  }

  void handleTap(int row, int col) {
    if (gameOver || board[row][col] != '') return;

    board[row][col] = currentPlayer;
    final cell = children.whereType<TicTacToeCell>().firstWhere(
      (c) => c.row == row && c.col == col,
    );
    cell.mark(currentPlayer);

    if (checkForWinner()) {
      messageText.text = "Player $currentPlayer wins";
      if (SettingsScreen.gameSoundOn) FlameAudio.play('win.wav');
      gameOver = true;
      _startConfetti();
      return;
    } else if (checkForDraw()) {
      messageText.text = "Draw!";
      gameOver = true;
      return;
    }

    currentPlayer = currentPlayer == 'X' ? 'O' : 'X';
    messageText.text = "Player $currentPlayer's turn";
  }

  bool checkForWinner() {
    final combos = [
      [
        [0, 0],
        [0, 1],
        [0, 2],
      ],
      [
        [1, 0],
        [1, 1],
        [1, 2],
      ],
      [
        [2, 0],
        [2, 1],
        [2, 2],
      ],
      [
        [0, 0],
        [1, 0],
        [2, 0],
      ],
      [
        [0, 1],
        [1, 1],
        [2, 1],
      ],
      [
        [0, 2],
        [1, 2],
        [2, 2],
      ],
      [
        [0, 0],
        [1, 1],
        [2, 2],
      ],
      [
        [0, 2],
        [1, 1],
        [2, 0],
      ],
    ];

    for (var combo in combos) {
      String first = board[combo[0][0]][combo[0][1]];
      if (first != '' &&
          first == board[combo[1][0]][combo[1][1]] &&
          first == board[combo[2][0]][combo[2][1]]) {
        return true;
      }
    }
    return false;
  }

  bool checkForDraw() => board.every((row) => row.every((cell) => cell != ''));

  void restartGame() {
    board = List.generate(3, (_) => List.filled(3, ''));
    currentPlayer = 'O';
    gameOver = false;
    messageText.text = "Player $currentPlayer's turn";

    for (var cell in children.whereType<TicTacToeCell>()) {
      cell.markSprite?.removeFromParent();
    }

    // Stop confetti
    confettiRunning = false;
    for (var c in confettiPieces) {
      c.removeFromParent();
    }
    confettiPieces.clear();
  }

  void _startConfetti() {
    if (confettiRunning) return;
    confettiRunning = true;
    print("Confetti has started");

    final size = findGame()?.size ?? Vector2(360, 640);

    void spawnConfettiPiece() {
      if (!confettiRunning) return;

      // Smaller size
      final double confettiSize = 4 + random.nextDouble() * 6;

      // Random shape
      final shapeType = random.nextInt(3);

      late PositionComponent confetti;

      final paint = Paint()
        ..color = Color.fromARGB(
          255,
          random.nextInt(256),
          random.nextInt(256),
          random.nextInt(256),
        );

      switch (shapeType) {
        case 0:
          confetti = RectangleComponent(
            size: Vector2(confettiSize, confettiSize * 1.5),
            paint: paint,
            position: Vector2(random.nextDouble() * size.x, -10),
            anchor: Anchor.center,
          );
          break;
        case 1:
          confetti = CircleComponent(
            radius: confettiSize / 2,
            paint: paint,
            position: Vector2(random.nextDouble() * size.x, -10),
            anchor: Anchor.center,
          );
          break;
        case 2:
          confetti = PolygonComponent(
            [
              Vector2(0, 0),
              Vector2(confettiSize, 0),
              Vector2(confettiSize / 2, confettiSize),
            ],
            paint: paint,
            position: Vector2(random.nextDouble() * size.x, -10),
            anchor: Anchor.center,
          );
          break;
      }

      confettiPieces.add(confetti);
      add(confetti);

      // falling with random speed
      final fallDuration = 1.5 + random.nextDouble() * 1.5;
      confetti.add(
        MoveEffect.to(
          Vector2(confetti.x, size.y + 50),
          EffectController(duration: fallDuration, curve: Curves.linear),
          onComplete: () {
            confetti.removeFromParent();
            confettiPieces.remove(confetti);
          },
        ),
      );
      // Random rotating
      confetti.add(
        RotateEffect.by(
          random.nextDouble() * pi * 4,
          EffectController(duration: fallDuration, curve: Curves.linear),
        ),
      );

      Future.delayed(const Duration(milliseconds: 15), spawnConfettiPiece);
    }

    // Start spawning
    spawnConfettiPiece();

    // Stop after 2 and half seconds.
    Future.delayed(const Duration(milliseconds: 2500), () {
      confettiRunning = false;
      print(
        "Confetti has stopped",
      ); //Used this to check if its loading and I'm not seeing it
    });
  }
}

class _PressdownButton extends SpriteComponent with TapCallbacks {
  final VoidCallback onPressed;
  final String imagePath;

  _PressdownButton({
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
    _bounceEffect();
    Future.delayed(Duration(milliseconds: 180), () => onPressed());
  }

  void _bounceEffect() {
    add(
      SequenceEffect([
        ScaleEffect.to(Vector2(0.9, 0.9), EffectController(duration: 0.05)),
        ScaleEffect.to(
          Vector2(1.05, 1.05),
          EffectController(duration: 0.08, curve: Curves.easeOut),
        ),
        ScaleEffect.to(
          Vector2(1.0, 1.0),
          EffectController(duration: 0.05, curve: Curves.easeIn),
        ),
      ]),
    );
  }
}
