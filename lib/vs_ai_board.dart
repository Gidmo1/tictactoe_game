// vs_ai_board.dart
import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/effects.dart';
import 'package:flutter/material.dart';
import 'package:flame_audio/flame_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tictactoe_game/confirmation_overlay.dart';
import 'package:tictactoe_game/end_match_overlay.dart';
import 'package:tictactoe_game/settings_screen.dart';
import 'ai.dart';
import 'models/user.dart' as app_user;

class TicTacToeVsAI extends Component {
  static String _randomDifficulty() {
    const difficulties = ['easy', 'medium', 'hard'];
    return difficulties[Random().nextInt(difficulties.length)];
  }

  // Keep constructor signature same
  final int? totalRounds;
  late String difficulty;

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

  late TextComponent scoreText;
  late SpriteComponent humanIcon;
  late SpriteComponent aiIcon;

  late TicTacToeAI ai;

  final double cellWidth = 390 / 3;
  final double cellHeight = 321 / 3;
  final double boardX = 4;
  final double boardY = 318;
  app_user.User loggedInUser;

  bool confettiRunning = false;
  final Random random = Random();
  final List<Component> confettiPieces = [];

  TicTacToeVsAI({
    app_user.User? loggedInUser,
    String? initialDifficulty,
    this.totalRounds,
  }) : loggedInUser =
           loggedInUser ??
           app_user.User(
             id: '',
             userName: 'Guest',
             providerId: '',
             providerName: '',
           ),
       difficulty = initialDifficulty ?? _randomDifficulty();

  // treat null totalRounds as 1
  int get _effectiveTotalRounds => totalRounds ?? 1;
  String get _roundsLabel => '${_effectiveTotalRounds}';

  @override
  Future<void> onLoad() async {
    ai = TicTacToeAI();
    resetState();

    final canvasSize = findGame()?.size ?? Vector2(360, 640);

    try {
      // Background
      final background = SpriteComponent()
        ..sprite = await Sprite.load('playscreen.png')
        ..size = canvasSize
        ..position = Vector2.zero();
      add(background);

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

    // Return button that asks for confirmation
    add(
      _PressdownIconButton(
        imagePath: 'return.png',
        position: Vector2(40, 180),
        size: Vector2(60, 60),
        onPressed: () {
          final flameGame = findGame();
          if (flameGame != null) {
            final dim = RectangleComponent(
              size: flameGame.size,
              paint: Paint()..color = Colors.black.withOpacity(0.6),
              priority: 1000000000000,
            );
            flameGame.add(dim);
            late ConfirmationOverlay overlay;
            overlay = ConfirmationOverlay(
              onYes: () async {
                //  Remove the overlay
                overlay.removeFromParent();
                dim.removeFromParent();

                //  If game isn't over, record as loss
                if (!gameOver) {
                  saveScore("loss");
                }

                //  Reset game state
                resetState();

                //  Clear board visuals
                for (var cell in children.whereType<TicTacToeCell>()) {
                  cell.markSprite?.removeFromParent();
                  cell.markSprite = null;
                }

                //  Reset score UI
                scoreText.text = "$humanScore - $aiScore";

                //  Clear confetti
                confettiRunning = false;
                for (var c in List.from(confettiPieces)) {
                  c.removeFromParent();
                }
                confettiPieces.clear();

                final router = (flameGame as dynamic).router;
                router?.pushNamed('menu');
              },

              onNo: () {
                overlay.removeFromParent();
                dim.removeFromParent();
              },
            );
            overlay.priority = 10000000000000;
            flameGame.add(overlay);
          }
        },
      ),
    );

    // Cells
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
    cell.mark(player);

    if (checkForWinner(player)) {
      if (player == humanPlayer) {
        humanScores[difficulty] = humanScore + 1;
      } else {
        aiScores[difficulty] = aiScore + 1;
      }
      endRound();
    } else if (checkForDraw()) {
      endRound();
    } else {
      currentPlayer = (player == humanPlayer) ? aiPlayer : humanPlayer;
    }

    scoreText.text = "$humanScore - $aiScore";
  }

  void aiMove() {
    if (gameOver) return;

    // Difficulty journey for AI
    int level;
    switch (difficulty) {
      case 'easy':
        level = 5;
        break;
      case 'medium':
        level = 15;
        break;
      case 'hard':
        level = 40;
        break;
      default:
        level = 50;
    }

    final move = ai.getMoveForLevel(board, level, humanPlayer, aiPlayer);
    if (move[0] != -1) {
      makeMove(move[0], move[1], aiPlayer);
    }
  }

  List<int> getAIMove(List<List<String>> board, String human, String aiPlayer) {
    int level;
    switch (difficulty) {
      case 'easy':
        level = 5;
        break;
      case 'medium':
        level = 15;
        break;
      case 'hard':
        level = 40;
        break;
      default:
        level = 50;
    }
    return ai.getMoveForLevel(board, level, human, aiPlayer);
  }

  void endRound() {
    gameOver = true;

    // single round matches
    final finished = (roundCount >= _effectiveTotalRounds);

    if (finished) {
      Future.delayed(const Duration(seconds: 1), () async {
        String result;
        if (humanScore > aiScore) {
          result = "win";
        } else if (aiScore > humanScore) {
          result = "loss";
        } else {
          result = "draw";
        }
        await saveScore(result);
        _startConfetti();

        final flameGame = findGame();
        if (flameGame != null) {
          final dim = RectangleComponent(
            size: flameGame.size,
            paint: Paint()..color = Colors.black.withOpacity(0.6),
            priority: 1000000000000,
          );
          flameGame.add(dim);

          final overlay = EndMatchOverlay(
            didWin: humanScore > aiScore,
            didDraw: (humanScore == aiScore),
            onNext: () {
              // Next = next level
              dim.removeFromParent();
              _advanceDifficulty();
              _resetScoresAndBoard();
            },
            onHome: () {
              dim.removeFromParent();

              // Advance difficulty (start next level)
              _advanceDifficulty();

              // Reset all logical data
              humanScores[difficulty] = 0;
              aiScores[difficulty] = 0;
              roundCounts[difficulty] = 1;
              boards[difficulty] = List.generate(3, (_) => List.filled(3, ''));

              // Reset player state
              gameOver = false;
              currentPlayer = humanPlayer;

              // Actually clear board visually
              for (var cell in List.from(children.whereType<TicTacToeCell>())) {
                cell.markSprite?.removeFromParent();
                cell.markSprite = null;
              }

              // Stop and clear confetti visuals too
              confettiRunning = false;
              for (var piece in List.from(confettiPieces)) {
                piece.removeFromParent();
              }
              confettiPieces.clear();

              // Update the score display
              scoreText.text = "$humanScore - $aiScore";

              // Go home
              final router = (flameGame as dynamic).router;
              router?.pushNamed('menu');
            },
          );

          overlay.priority = 1000000000001;
          flameGame.add(overlay);
        }
      });
    } else {
      roundCounts[difficulty] = roundCount + 1;
      Future.delayed(const Duration(seconds: 1), restartBoard);
    }
  }

  void _advanceDifficulty() {
    if (difficulty == 'easy') {
      difficulty = 'medium';
    } else if (difficulty == 'medium') {
      difficulty = 'hard';
    } else {
      difficulty = 'hard';
    }
  }

  void _resetScoresAndBoard() {
    // Reset scores and board for the new level
    humanScores[difficulty] = 0;
    aiScores[difficulty] = 0;
    roundCounts[difficulty] = 1;

    // Clear cell marks
    for (var cell in children.whereType<TicTacToeCell>()) {
      cell.markSprite?.removeFromParent();
      cell.markSprite = null;
    }

    // Update UI
    scoreText.text = "$humanScore - $aiScore";

    gameOver = false;
    currentPlayer = humanPlayer;

    // stop confetti
    confettiRunning = false;
    for (var c in confettiPieces) {
      c.removeFromParent();
    }
    confettiPieces.clear();
  }

  // Save score to firebase or on device if user is guest
  Future<void> saveScore(String result) async {
    if (loggedInUser.id.isEmpty) {
      // Guest mode
      final prefs = await SharedPreferences.getInstance();
      final key = 'guest_scores_$difficulty';

      List<Map<String, dynamic>> scores = [];
      final saved = prefs.getString(key);
      if (saved != null) {
        scores = List<Map<String, dynamic>>.from(json.decode(saved));
      }

      scores.add({
        'result': result,
        'difficulty': difficulty,
        'humanScore': humanScore,
        'aiScore': aiScore,
        'roundsPlayed': roundCount,
        'totalRounds': _effectiveTotalRounds,
        'timestamp': DateTime.now().toIso8601String(),
      });
      await prefs.setString(key, json.encode(scores));
      return;
    }

    // Logged in user using cloud function
    final dataToSend = {
      'playerId': loggedInUser.id,
      'result': result,
      'mode': 'vs_ai',
      'difficulty': difficulty,
      'humanScore': humanScore,
      'aiScore': aiScore,
      'roundsPlayed': roundCount,
      'totalRounds': _effectiveTotalRounds,
      'timestamp': DateTime.now().toIso8601String(),
    };

    try {
      final callable = FirebaseFunctions.instanceFor(
        region: 'us-central1',
      ).httpsCallable('updateScore');
      final functionResult = await callable.call(dataToSend);
    } catch (e) {
      print("Error saving score to Firebase: $e");
    }
  }

  // Save guest scores after login
  Future<void> pushGuestScores() async {
    if (loggedInUser.id.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();

    for (var diff in ['easy', 'medium', 'hard']) {
      final key = 'guest_scores_$diff';
      final saved = prefs.getString(key);
      if (saved != null) {
        final scores = List<Map<String, dynamic>>.from(json.decode(saved));
        for (var s in scores) {
          await saveScore(s['result']);
        }
        prefs.remove(key);
      }
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
      cell.markSprite = null;
    }

    scoreText.text = "$humanScore - $aiScore";

    confettiRunning = false;
    for (var c in confettiPieces) {
      c.removeFromParent();
    }
    confettiPieces.clear();
  }

  void _startConfetti() {
    if (confettiRunning) return;
    confettiRunning = true;

    final size = findGame()?.size ?? Vector2(360, 640);

    void spawnConfettiPiece() {
      if (!confettiRunning) return;

      final double confettiSize = 4 + random.nextDouble() * 6;
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
        default:
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
      }

      confettiPieces.add(confetti);
      add(confetti);

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

      confetti.add(
        RotateEffect.by(
          random.nextDouble() * pi * 4,
          EffectController(duration: fallDuration, curve: Curves.linear),
        ),
      );

      Future.delayed(const Duration(milliseconds: 15), spawnConfettiPiece);
    }

    spawnConfettiPiece();

    Future.delayed(const Duration(milliseconds: 2500), () {
      confettiRunning = false;
    });
  }

  /*void restartMatch() {
    for (var key in boards.keys) {
      boards[key] = List.generate(3, (_) => List.filled(3, ''));
      humanScores[key] = 0;
      aiScores[key] = 0;
      roundCounts[key] = 1;
    }
    for (var cell in children.whereType<TicTacToeCell>()) {
      cell.markSprite?.removeFromParent();
      cell.markSprite = null;
    }
    currentPlayer = humanPlayer;
    gameOver = false;

    scoreText.text = "$humanScore - $aiScore";
  }*/

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
}

// TicTacToeCell
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
    if (SettingsScreen.buttonSoundOn) FlameAudio.play('tap.wav');
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

class _PressdownIconButton extends SpriteComponent with TapCallbacks {
  final VoidCallback onPressed;
  final String imagePath;

  _PressdownIconButton({
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
    if (SettingsScreen.buttonSoundOn) FlameAudio.play('button.wav');
    _bounceEffect();
    Future.delayed(const Duration(milliseconds: 120), () => onPressed());
  }

  void _bounceEffect() {
    add(
      SequenceEffect([
        ScaleEffect.to(Vector2(0.9, 0.9), EffectController(duration: 0.04)),
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
