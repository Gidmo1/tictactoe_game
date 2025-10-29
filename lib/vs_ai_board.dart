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
  final String humanPlayer = 'X';
  final String aiPlayer = 'O';
  String currentPlayer = 'X';
  bool gameOver = false;

  final double cellWidth = 390 / 3;
  final double cellHeight = 321 / 3;
  final double boardX = 4;
  final double boardY = 318;
  app_user.User loggedInUser;

  late TicTacToeAI ai;
  late TextComponent scoreText;
  late SpriteComponent humanIcon;
  late SpriteComponent aiIcon;
  late TextComponent levelText;

  int currentLevel = 1;
  bool confettiRunning = false;
  final Random random = Random();
  final List<Component> confettiPieces = [];

  List<List<String>> board = List.generate(3, (_) => List.filled(3, ''));

  TicTacToeVsAI({app_user.User? loggedInUser})
    : loggedInUser =
          loggedInUser ??
          app_user.User(
            id: '',
            userName: 'Guest',
            providerId: '',
            providerName: '',
          );

  @override
  Future<void> onLoad() async {
    ai = TicTacToeAI();
    final canvasSize = findGame()?.size ?? Vector2(360, 640);

    try {
      // Background
      final background = SpriteComponent()
        ..sprite = await Sprite.load('playscreen.png')
        ..size = canvasSize
        ..position = Vector2.zero();
      add(background);

      // Player icons
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

      // Load and display level
      final prefs = await SharedPreferences.getInstance();
      currentLevel = prefs.getInt('ai_level') ?? 1;
      if (currentLevel < 1) currentLevel = 1;

      levelText = TextComponent(
        text: 'Level $currentLevel',
        position: Vector2(canvasSize.x / 2, 50),
        anchor: Anchor.center,
        textRenderer: TextPaint(
          style: const TextStyle(
            fontSize: 28,
            color: Colors.yellow,
            fontWeight: FontWeight.bold,
            shadows: [
              Shadow(blurRadius: 3, color: Colors.black, offset: Offset(0, 2)),
            ],
          ),
        ),
      );
      add(levelText);

      // Empty score text (no scoring system)
      scoreText = TextComponent(
        text: "",
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
          text: 'Error loading VS Computer screen.',
          position: Vector2(180, 320),
          anchor: Anchor.center,
          textRenderer: TextPaint(
            style: const TextStyle(fontSize: 24, color: Colors.redAccent),
          ),
        ),
      );
    }

    // Return button
    add(
      _PressdownIconButton(
        imagePath: 'return.png',
        position: Vector2(40, 180),
        size: Vector2(60, 60),
        onPressed: () async {
          final flameGame = findGame();
          if (flameGame == null) return;

          final dim = RectangleComponent(
            size: flameGame.size,
            paint: Paint()..color = Colors.black.withOpacity(0.6),
            priority: 1000000000000,
          );
          flameGame.add(dim);

          late ConfirmationOverlay overlay;
          overlay = ConfirmationOverlay(
            onYes: () async {
              overlay.removeFromParent();
              dim.removeFromParent();

              if (!gameOver) await saveScore("loss");
              restartBoard();

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
        },
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
      Future.delayed(const Duration(milliseconds: 500), aiMove);
    }
  }

  void makeMove(int row, int col, String player) {
    board[row][col] = player;

    final cell = children.whereType<TicTacToeCell>().firstWhere(
      (c) => c.row == row && c.col == col,
    );
    cell.mark(player);

    if (checkForWinner(player) || checkForDraw()) {
      endRound();
    } else {
      currentPlayer = (player == humanPlayer) ? aiPlayer : humanPlayer;
    }
  }

  void aiMove() {
    if (gameOver) return;
    final move = ai.getMoveForLevel(board, 15, aiPlayer, humanPlayer);
    if (move[0] != -1) makeMove(move[0], move[1], aiPlayer);
  }

  void endRound() {
    gameOver = true;
    Future.delayed(const Duration(seconds: 1), () async {
      String result;
      if (checkForWinner(humanPlayer)) {
        result = "win";
        _startConfetti();
      } else if (checkForWinner(aiPlayer)) {
        result = "loss";
      } else {
        result = "draw";
      }

      await saveScore(result);

      final flameGame = findGame();
      if (flameGame != null) {
        final dim = RectangleComponent(
          size: flameGame.size,
          paint: Paint()..color = Colors.black.withOpacity(0.6),
          priority: 1000000000000,
        );
        flameGame.add(dim);

        final overlay = EndMatchOverlay(
          didWin: result == "win",
          didDraw: result == "draw",
          onNext: () async {
            // Always increase level
            currentLevel++;
            levelText.text = 'Level $currentLevel';
            final prefs = await SharedPreferences.getInstance();
            await prefs.setInt('ai_level', currentLevel);

            dim.removeFromParent();
            restartBoard();
          },
          onHome: () {
            dim.removeFromParent();
            restartBoard();
            final router = (flameGame as dynamic).router;
            router?.pushNamed('menu');
          },
        );

        overlay.priority = 1000000000001;
        flameGame.add(overlay);
      }
    });
  }

  void restartBoard() {
    board = List.generate(3, (_) => List.filled(3, ''));
    gameOver = false;
    currentPlayer = humanPlayer;

    for (var cell in children.whereType<TicTacToeCell>()) {
      cell.markSprite?.removeFromParent();
      cell.markSprite = null;
    }

    confettiRunning = false;
    for (var c in List.from(confettiPieces)) {
      c.removeFromParent();
    }
    confettiPieces.clear();
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
      (c) =>
          board[c[0][0]][c[0][1]] == player &&
          board[c[1][0]][c[1][1]] == player &&
          board[c[2][0]][c[2][1]] == player,
    );
  }

  bool checkForDraw() =>
      board.every((row) => row.every((cell) => cell.isNotEmpty));

  void _startConfetti() {
    if (confettiRunning) return;
    confettiRunning = true;
    final size = findGame()?.size ?? Vector2(360, 640);

    void spawnPiece() {
      if (!confettiRunning) return;
      final s = 4 + random.nextDouble() * 6;
      final paint = Paint()
        ..color = Color.fromARGB(
          255,
          random.nextInt(256),
          random.nextInt(256),
          random.nextInt(256),
        );
      final shape = random.nextInt(3);
      PositionComponent piece;

      switch (shape) {
        case 0:
          piece = RectangleComponent(
            size: Vector2(s, s * 1.5),
            paint: paint,
            position: Vector2(random.nextDouble() * size.x, -10),
            anchor: Anchor.center,
          );
          break;
        case 1:
          piece = CircleComponent(
            radius: s / 2,
            paint: paint,
            position: Vector2(random.nextDouble() * size.x, -10),
            anchor: Anchor.center,
          );
          break;
        default:
          piece = PolygonComponent(
            [Vector2(0, 0), Vector2(s, 0), Vector2(s / 2, s)],
            paint: paint,
            position: Vector2(random.nextDouble() * size.x, -10),
            anchor: Anchor.center,
          );
      }

      confettiPieces.add(piece);
      add(piece);
      final fall = 1.5 + random.nextDouble() * 1.5;
      piece.add(
        MoveEffect.to(
          Vector2(piece.x, size.y + 50),
          EffectController(duration: fall, curve: Curves.linear),
          onComplete: () {
            piece.removeFromParent();
            confettiPieces.remove(piece);
          },
        ),
      );
      piece.add(
        RotateEffect.by(
          random.nextDouble() * pi * 4,
          EffectController(duration: fall),
        ),
      );
      Future.delayed(const Duration(milliseconds: 15), spawnPiece);
    }

    spawnPiece();
    Future.delayed(const Duration(milliseconds: 2500), () {
      confettiRunning = false;
    });
  }

  Future<void> saveScore(String result) async {
    if (loggedInUser.id.isEmpty) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('guest_score', json.encode({'result': result}));
      return;
    }
    final data = {
      'playerId': loggedInUser.id,
      'result': result,
      'mode': 'vs_ai',
      'timestamp': DateTime.now().toIso8601String(),
    };
    try {
      final callable = FirebaseFunctions.instanceFor(
        region: 'us-central1',
      ).httpsCallable('updateScore');
      await callable.call(data);
    } catch (e) {
      print("Error saving score to Firebase: $e");
    }
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
    if (parent is TicTacToeVsAI) {
      final vs = parent as TicTacToeVsAI;
      if (SettingsScreen.buttonSoundOn) FlameAudio.play('tap.wav');
      vs.handleTap(row, col);
    }
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
  Future<void> onLoad() async => sprite = await Sprite.load(imagePath);

  @override
  void onTapDown(TapDownEvent event) {
    if (SettingsScreen.buttonSoundOn) FlameAudio.play('button.wav');
    _bounceEffect();
    Future.delayed(const Duration(milliseconds: 120), onPressed);
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
