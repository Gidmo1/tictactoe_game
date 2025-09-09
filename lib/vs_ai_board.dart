import 'dart:async';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/effects.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flame_audio/flame_audio.dart';
import 'package:tictactoe_game/settings_screen.dart';

import 'ai.dart';
import 'board.dart'; // for TicTacToeCell + ArcadeButton reuse

class TicTacToeVsAI extends Component {
  static String selectedDifficulty = 'easy';
  // Separate memory for each difficulty
  Map<String, List<List<String>>> boards = {
    'easy': List.generate(3, (_) => List.filled(3, '')),
    'medium': List.generate(3, (_) => List.filled(3, '')),
    'hard': List.generate(3, (_) => List.filled(3, '')),
  };
  Map<String, int> humanScores = {'easy': 0, 'medium': 0, 'hard': 0};
  Map<String, int> aiScores = {'easy': 0, 'medium': 0, 'hard': 0};
  Map<String, int> roundCounts = {'easy': 1, 'medium': 1, 'hard': 1};

  List<List<String>> get board => boards[difficulty]!;
  int get humanScore => humanScores[difficulty]!;
  int get aiScore => aiScores[difficulty]!;
  int get roundCount => roundCounts[difficulty]!;

  String humanPlayer = 'X';
  String aiPlayer = 'O';
  String currentPlayer = 'X';
  bool gameOver = false;

  void resetState() {
    boards[difficulty] = List.generate(3, (_) => List.filled(3, ''));
    currentPlayer = 'X';
    gameOver = false;
    roundCounts[difficulty] = 1;
    humanScores[difficulty] = 0;
    aiScores[difficulty] = 0;
  }

  late TextComponent messageText;
  late TextComponent scoreText;

  final ai = TicTacToeAI();
  String difficulty = 'easy';

  final double cellWidth = 390 / 3;
  final double cellHeight = 321 / 3;
  final double boardX = 4;
  final double boardY = 318;

  @override
  Future<void> onLoad() async {
    difficulty = TicTacToeVsAI.selectedDifficulty;
    resetState();

    final canvasSize = findGame()?.size ?? Vector2(360, 640);

    // Background
    final background = SpriteComponent()
      ..sprite = await Sprite.load('playscreen.png')
      ..size = canvasSize
      ..position = Vector2.zero();
    add(background);

    // Scoreboard image (move up and minimize size)
    final scoreboardWidth = 180.0;
    final scoreboardHeight = 60.0;
    final scoreboardY = boardY - 160; // Move up a bit
    final scoreboard = SpriteComponent()
      ..sprite = await Sprite.load('scoreboard.png')
      ..size = Vector2(scoreboardWidth, scoreboardHeight)
      ..position = Vector2((canvasSize.x - scoreboardWidth) / 2, scoreboardY);
    add(scoreboard);

    // Score text (just numbers, centered on scoreboard, improved style)
    scoreText = TextComponent(
      text: "$humanScore - $aiScore",
      position: Vector2(canvasSize.x / 2, scoreboardY + scoreboardHeight / 2),
      anchor: Anchor.center,
      textRenderer: TextPaint(
        style: const TextStyle(
          fontSize: 32,
          color: Color(0xFF1B5E20), // dark green for contrast
          fontWeight: FontWeight.w900,
          shadows: [
            Shadow(blurRadius: 4, color: Colors.white, offset: Offset(0, 2)),
          ],
        ),
      ),
    );
    add(scoreText);

    // Message text (placed below scoreboard, not overlapping)
    messageText = TextComponent(
      text: "Your turn",
      position: Vector2(canvasSize.x / 2, scoreboardY + scoreboardHeight + 20),
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

    // Return button
    add(
      _ArcadeButton(
        imagePath: 'return.png',
        position: Vector2(40, 180),
        size: Vector2(60, 60),
        onPressed: () {
          final flameGame = findGame();
          if (flameGame != null) {
            final router = (flameGame as dynamic).router;
            router?.pushNamed('difficulty');
          }
        },
      ),
    );

    // Restart button (resets match scores)
    add(
      _ArcadeButton(
        imagePath: 'restart.png',
        position: Vector2(canvasSize.x / 2, canvasSize.y - 70),
        size: Vector2(80, 80),
        onPressed: restartMatch,
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
    if (gameOver || currentPlayer != humanPlayer) return;
    if (board[row][col] != '') return;

    makeMove(row, col, humanPlayer);

    if (!gameOver) {
      Future.delayed(const Duration(milliseconds: 500), () {
        aiMove();
      });
    }
  }

  void makeMove(int row, int col, String player) {
    board[row][col] = player;
    final cell = children.whereType<TicTacToeCell>().firstWhere(
      (c) => c.row == row && c.col == col,
    );
    cell.mark(player);

    if (checkForWinner(player)) {
      endRound(
        player == humanPlayer ? "You win this round" : "AI wins this round",
        player,
      );
      return;
    } else if (checkForDraw()) {
      endRound("Draw", "");
      return;
    }

    currentPlayer = (player == humanPlayer) ? aiPlayer : humanPlayer;
    messageText.text = currentPlayer == humanPlayer ? "Your turn" : "AI's turn";
  }

  void aiMove() {
    if (gameOver) return;
    List<int> move;
    if (difficulty == 'easy') {
      move = ai.getMove(board);
    } else if (difficulty == 'medium') {
      move = ai.getMediumMove(board, humanPlayer, aiPlayer);
    } else {
      move = ai.getHardMove(board, humanPlayer, aiPlayer);
    }
    if (move[0] == -1) return;
    makeMove(move[0], move[1], aiPlayer);
  }

  void endRound(String result, String winner) {
    messageText.text = result;
    if (SettingsScreen.gameSoundOn)
      FlameAudio.play(winner == humanPlayer ? 'win.wav' : 'lose.wav');
    gameOver = true;

    if (winner == humanPlayer) {
      humanScores[difficulty] = humanScores[difficulty]! + 1;
    } else if (winner == aiPlayer) {
      aiScores[difficulty] = aiScores[difficulty]! + 1;
    }

    scoreText.text = "You $humanScore - $aiScore AI (Round $roundCount/5)";

    if (roundCount >= 5) {
      Future.delayed(const Duration(seconds: 2), () {
        messageText.text = humanScore > aiScore
            ? "You are the winner of this match"
            : (aiScore > humanScore
                  ? "AI is the winner of this match"
                  : "The match is a draw");
      });
    } else {
      roundCounts[difficulty] = roundCounts[difficulty]! + 1;
      Future.delayed(const Duration(seconds: 2), restartBoard);
    }
  }

  bool checkForWinner(String player) {
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
      if (board[combo[0][0]][combo[0][1]] == player &&
          board[combo[1][0]][combo[1][1]] == player &&
          board[combo[2][0]][combo[2][1]] == player) {
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

  void restartBoard() {
    boards[difficulty] = List.generate(3, (_) => List.filled(3, ''));
    gameOver = false;
    currentPlayer = humanPlayer;
    messageText.text = "Your turn";

    for (var cell in children.whereType<TicTacToeCell>()) {
      cell.markSprite?.removeFromParent();
    }

    scoreText.text = "You $humanScore - $aiScore AI (Round $roundCount/5)";
  }

  void restartMatch() {
    boards[difficulty] = List.generate(3, (_) => List.filled(3, ''));
    humanScores[difficulty] = 0;
    aiScores[difficulty] = 0;
    roundCounts[difficulty] = 1;
    gameOver = false;
    currentPlayer = humanPlayer;
    messageText.text = "Your turn";

    for (var cell in children.whereType<TicTacToeCell>()) {
      cell.markSprite?.removeFromParent();
    }

    scoreText.text = "$humanScore - $aiScore";
  }
}

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
    if (SettingsScreen.buttonSoundOn) FlameAudio.play('tap.wav');
    _bounceEffect();
    Future.delayed(const Duration(milliseconds: 180), () => onPressed());
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
