import 'dart:async';
import 'dart:math';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/effects.dart';
import 'package:flutter/material.dart';
import 'package:flame_audio/flame_audio.dart';
import 'package:tictactoe_game/settings_screen.dart';
import 'ai.dart';
import 'models/score.dart';
import 'service/score_service.dart';
import 'models/user.dart' as app_user;

class TicTacToeVsAI extends Component {
  static String _randomDifficulty() {
    const difficulties = ['easy', 'medium', 'hard'];
    return difficulties[Random().nextInt(difficulties.length)];
  }

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
    for (var key in boards.keys) {
      boards[key] = List.generate(3, (_) => List.filled(3, ''));
      humanScores[key] = 0;
      aiScores[key] = 0;
      roundCounts[key] = 1;
    }
    currentPlayer = humanPlayer;
    gameOver = false;
  }

  late TextComponent scoreText;
  late TextComponent roundText;
  late SpriteComponent humanIcon;
  late SpriteComponent aiIcon;

  late TicTacToeAI ai;
  late String difficulty;

  final double cellWidth = 390 / 3;
  final double cellHeight = 321 / 3;
  final double boardX = 4;
  final double boardY = 318;
  final app_user.User? loggedInUser;

  TicTacToeVsAI({this.loggedInUser});

  @override
  Future<void> onLoad() async {
    ai = TicTacToeAI();
    difficulty = _randomDifficulty();
    resetState();

    final canvasSize = findGame()?.size ?? Vector2(360, 640);

    try {
      // Background
      final background = SpriteComponent()
        ..sprite = await Sprite.load('playscreen.png')
        ..size = canvasSize
        ..position = Vector2.zero();
      add(background);

      // Score icons
      final iconSize = 40.0;
      humanIcon = SpriteComponent()
        ..sprite = await Sprite.load('X.png')
        ..size = Vector2(iconSize, iconSize)
        ..position = Vector2(60, 50);
      add(humanIcon);

      aiIcon = SpriteComponent()
        ..sprite = await Sprite.load('O.png')
        ..size = Vector2(iconSize, iconSize)
        ..position = Vector2(canvasSize.x - 100, 50);
      add(aiIcon);

      // Score text
      scoreText = TextComponent(
        text: "$humanScore - $aiScore",
        position: Vector2(canvasSize.x / 2, 60),
        anchor: Anchor.center,
        textRenderer: TextPaint(
          style: const TextStyle(
            fontSize: 32,
            color: Colors.white,
            fontWeight: FontWeight.bold,
            shadows: [
              Shadow(blurRadius: 2, color: Colors.black, offset: Offset(0, 1)),
            ],
          ),
        ),
      );
      add(scoreText);

      // Rounds played
      roundText = TextComponent(
        text: "Round $roundCount/5",
        position: Vector2(canvasSize.x / 2, 100),
        anchor: Anchor.center,
        textRenderer: TextPaint(
          style: const TextStyle(
            fontSize: 20,
            color: Colors.amber,
            fontWeight: FontWeight.bold,
            shadows: [
              Shadow(blurRadius: 2, color: Colors.black, offset: Offset(0, 1)),
            ],
          ),
        ),
      );
      add(roundText);

      // Difficulty text
      add(
        TextComponent(
          text: 'Difficulty: ' + difficulty.toUpperCase(),
          position: Vector2(canvasSize.x / 2, 250),
          anchor: Anchor.center,
          textRenderer: TextPaint(
            style: const TextStyle(
              fontSize: 18,
              color: Colors.amber,
              fontWeight: FontWeight.bold,
              shadows: [
                Shadow(
                  blurRadius: 2,
                  color: Colors.black,
                  offset: Offset(0, 1),
                ),
              ],
            ),
          ),
        ),
      );
    } catch (e) {
      add(
        TextComponent(
          text: 'Error loading VS Computer screen',
          position: Vector2(canvasSize.x / 2, canvasSize.y / 2),
          anchor: Anchor.center,
          textRenderer: TextPaint(
            style: const TextStyle(fontSize: 24, color: Colors.redAccent),
          ),
        ),
      );
    }

    // Return button
    add(
      _ArcadeButton(
        imagePath: 'return.png',
        position: Vector2(40, 180),
        size: Vector2(60, 60),
        onPressed: () {
          resetState();
          final flameGame = findGame();
          if (flameGame != null) {
            final router = (flameGame as dynamic).router;
            router?.pushNamed('menu');
          }
        },
      ),
    );

    // Restart button
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
        if (!gameOver) aiMove();
      });
    }
  }

  void makeMove(int row, int col, String player) {
    board[row][col] = player;
    final cell = children.whereType<TicTacToeCell>().firstWhere(
      (c) => c.row == row && c.col == col,
    );
    cell.mark(player); // ← SHOW X/O

    if (checkForWinner(player)) {
      if (player == humanPlayer) {
        humanScores[difficulty] = humanScore + 1;
        saveScore("win");
      } else {
        aiScores[difficulty] = aiScore + 1;
        saveScore("loss");
      }
      endRound(player);
    } else if (checkForDraw()) {
      saveScore("draw");
      endRound('');
    } else {
      currentPlayer = (player == humanPlayer) ? aiPlayer : humanPlayer;
    }

    scoreText.text = "$humanScore - $aiScore";
  }

  List<int> getAIMove(List<List<String>> board, String human, String aiPlayer) {
    switch (difficulty) {
      case 'easy':
        return ai.getMove(board);
      case 'medium':
        return ai.getMediumMove(board, human, aiPlayer);
      case 'hard':
        return ai.getHardMove(board, human, aiPlayer);
      default:
        return ai.getMove(board);
    }
  }

  void aiMove() {
    if (gameOver) return;
    final move = getAIMove(board, humanPlayer, aiPlayer);
    if (move[0] != -1) {
      makeMove(move[0], move[1], aiPlayer);
    }
  }

  void endRound(String winner) {
    gameOver = true;

    if (roundCount >= 5) {
      Future.delayed(const Duration(seconds: 2), () {
        if (humanScore > aiScore) {
          scoreText.text = "You win the match!";
        } else if (aiScore > humanScore) {
          scoreText.text = "AI wins the match!";
        } else {
          scoreText.text = "Match is a draw.";
        }
      });
    } else {
      roundCounts[difficulty] = roundCount + 1;
      Future.delayed(const Duration(seconds: 2), restartBoard);
    }

    roundText.text = "Round $roundCount/5";
  }

  Future<void> saveScore(String result) async {
    if (loggedInUser == null) return;

    // Translate result into win/loss/draw increments
    int win = 0, loss = 0, draw = 0;
    if (result == "win") win = 1;
    if (result == "loss") loss = 1;
    if (result == "draw") draw = 1;

    final score = Score(
      playerId: loggedInUser!.id,
      playerName: loggedInUser!.userName,
      wins: win,
      losses: loss,
      draws: draw,
    );

    await ScoreService().updateScore(score);
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
    return combos.any(
      (combo) =>
          board[combo[0][0]][combo[0][1]] == player &&
          board[combo[1][0]][combo[1][1]] == player &&
          board[combo[2][0]][combo[2][1]] == player,
    );
  }

  bool checkForDraw() {
    return board.every((row) => row.every((cell) => cell != ''));
  }

  void restartBoard() {
    boards[difficulty] = List.generate(3, (_) => List.filled(3, ''));
    gameOver = false;
    currentPlayer = humanPlayer;

    for (var cell in children.whereType<TicTacToeCell>()) {
      cell.markSprite?.removeFromParent();
    }

    scoreText.text = "$humanScore - $aiScore";
    roundText.text = "Round $roundCount/5";
  }

  void restartMatch() {
    resetState();
    for (var cell in children.whereType<TicTacToeCell>()) {
      cell.markSprite?.removeFromParent();
    }
    scoreText.text = "$humanScore - $aiScore";
    roundText.text = "Round $roundCount/5";
  }
}

class TicTacToeCell extends PositionComponent with TapCallbacks {
  TicTacToeCell({
    required this.row,
    required this.col,
    required super.position,
    required super.size,
  });

  final int row;
  final int col;
  SpriteComponent? markSprite;
  @override
  void onTapDown(TapDownEvent event) {
    event.handled = true;
    (parent as TicTacToeVsAI).handleTap(row, col);
  }

  void mark(String player) async {
    markSprite?.removeFromParent();
    markSprite = SpriteComponent(
      sprite: await Sprite.load(player == 'X' ? 'X.png' : 'O.png'),
      size: Vector2(70, 70),
      anchor: Anchor.center,
      position: size / 2,
    );
    add(markSprite!);
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
