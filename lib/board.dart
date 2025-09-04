import 'dart:async';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/effects.dart';
import 'package:flutter/material.dart';
import 'package:flame_audio/flame_audio.dart';

// -------------------- Tic Tac Toe Cell --------------------
class TicTacToeCell extends PositionComponent with TapCallbacks {
  final int row, col;
  final Function(int, int) onTap;
  SpriteComponent? markSprite;

  TicTacToeCell({
    required this.row,
    required this.col,
    required this.onTap,
    required Vector2 position,
    required Vector2 size,
  }) : super(position: position, size: size);

  void mark(String symbol) async {
    markSprite?.removeFromParent();
    final spritePath = symbol == 'X' ? 'X.png' : 'O.png';
    markSprite = SpriteComponent()
      ..sprite = await Sprite.load(spritePath)
      ..size = Vector2(70, 70)
      ..anchor = Anchor.center
      ..position = size / 2;
    add(markSprite!);
  }

  @override
  void onTapDown(TapDownEvent event) {
    FlameAudio.play('tap.wav');
    onTap(row, col);
  }
}

// -------------------- Tic Tac Toe Board --------------------
class TicTacToeBoard extends Component {
  List<List<String>> board = List.generate(3, (_) => List.filled(3, ''));
  String currentPlayer = 'O';
  late TextComponent messageText;
  bool gameOver = false;

  final double cellWidth = 390 / 3;
  final double cellHeight = 321 / 3;
  final double boardX = 4;
  final double boardY = 318;

  @override
  Future<void> onLoad() async {
    final canvasSize = findGame()?.size ?? Vector2(360, 640);

    // Background
    final background = SpriteComponent()
      ..sprite = await Sprite.load('playscreen.png')
      ..size = canvasSize
      ..position = Vector2.zero();
    add(background);

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

    // Arcade-style return button
    add(
      _ArcadeButton(
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

    // Arcade-style settings button
    add(
      _ArcadeButton(
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

    // Arcade-style restart button
    add(
      _ArcadeButton(
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
            onTap: handleTap,
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
    if (gameOver) return;
    if (board[row][col] != '') return;

    board[row][col] = currentPlayer;
    final cell = children.whereType<TicTacToeCell>().firstWhere(
      (c) => c.row == row && c.col == col,
    );
    cell.mark(currentPlayer);

    if (checkForWinner()) {
      messageText.text = "Player $currentPlayer wins";
      FlameAudio.play('win.wav');
      gameOver = true;
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

  bool checkForDraw() {
    for (var row in board) {
      for (var cell in row) {
        if (cell == '') return false;
      }
    }
    return true;
  }

  void restartGame() {
    board = List.generate(3, (_) => List.filled(3, ''));
    currentPlayer = 'O';
    gameOver = false;
    messageText.text = "Player $currentPlayer's turn";

    for (var cell in children.whereType<TicTacToeCell>()) {
      cell.markSprite?.removeFromParent();
    }
  }
}

// -------------------- Arcade-style Button --------------------
class _ArcadeButton extends SpriteComponent with TapCallbacks {
  final VoidCallback onPressed;
  final String imagePath;

  _ArcadeButton({
    required this.imagePath,
    required Vector2 position,
    required Vector2 size,
    required this.onPressed,
  }) : super(size: size, position: position, anchor: Anchor.center);

  @override
  Future<void> onLoad() async {
    sprite = await Sprite.load(imagePath);
  }

  @override
  void onTapDown(TapDownEvent event) {
    FlameAudio.play('tap.wav');
    _bounceEffect();

    // Wait so you can see the bounce
    Future.delayed(Duration(milliseconds: 180), () => onPressed());
  }

  void _bounceEffect() {
    // squash -> overshoot -> settle
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
