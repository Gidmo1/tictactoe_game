import 'dart:async';
// dart:convert not required here
import 'dart:math';
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
import 'service/guest_service.dart';
import 'service/score_service.dart';
import 'models/score.dart';

class TicTacToeVsAI extends Component {
  String humanPlayer = 'X';
  String aiPlayer = 'O';
  String currentPlayer = 'X';
  bool humanIsX = true;
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
  // Tunable AI delays (ms): aiReactionDelayMs and aiStartDelayMs.
  int aiReactionDelayMs = 500;
  int aiStartDelayMs = 0;

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

    // Load AI difficulty from local prefs
    try {
      final prefs = await SharedPreferences.getInstance();
      currentLevel = prefs.getInt('ai_level') ?? 1;
      if (currentLevel < 1) currentLevel = 1;
      // Load tuned delays if present. Keep sensible defaults otherwise.
      aiReactionDelayMs =
          prefs.getInt('ai_reaction_delay_ms') ?? aiReactionDelayMs;
      aiStartDelayMs = prefs.getInt('ai_start_delay_ms') ?? aiStartDelayMs;
    } catch (_) {
      currentLevel = 1;
    }

    // Load background and UI
    try {
      final background = SpriteComponent()
        ..sprite =
            await (findGame()?.loadSprite('playscreen.png') ??
                Sprite.load('playscreen.png'))
        ..size = canvasSize
        ..position = Vector2.zero();
      add(background);

      final iconSize = 40.0;
      humanIcon = SpriteComponent()
        ..size = Vector2(iconSize, iconSize)
        ..position = Vector2(60, 50);
      add(humanIcon);
      aiIcon = SpriteComponent()
        ..size = Vector2(iconSize, iconSize)
        ..position = Vector2(canvasSize.x - 100, 50);
      add(aiIcon);

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

    // Apply symbol settings (loads correct sprites and ensures X starts)
    try {
      final prefs = await SharedPreferences.getInstance();
      humanIsX = prefs.getBool('human_is_x') ?? true;
    } catch (_) {
      humanIsX = true;
    }
    await applySymbolSettings();

    // Settings button
    add(
      _PressdownButton(
        imagePath: 'settings.png',
        position: Vector2(340, 760),
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

    // Return button
    add(
      _PressdownButton(
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
            onYes: () {
              // close overlay first
              overlay.removeFromParent();
              dim.removeFromParent();

              // save score in background so UI stays snappy
              if (!gameOver) {
                saveScore("loss");
              }
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
    // Use a tunable reaction delay so different devices can adjust AI responsiveness.
    if (!gameOver) {
      if (aiReactionDelayMs <= 0) {
        // immediate (next microtask) to avoid blocking UI
        Future.microtask(() {
          try {
            aiMove();
          } catch (_) {}
        });
      } else {
        Future.delayed(Duration(milliseconds: aiReactionDelayMs), aiMove);
      }
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
    final move = ai.getMoveForLevel(board, currentLevel, aiPlayer, humanPlayer);
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
          showSignInPrompt: false,
          onNext: () async {
            currentLevel++;
            levelText.text = 'Level $currentLevel';
            final prefs = await SharedPreferences.getInstance();
            await prefs.setInt('ai_level', currentLevel);

            // Rotate symbols: flip whether the human is X or O for next level
            humanIsX = !humanIsX;
            await prefs.setBool('human_is_x', humanIsX);
            await applySymbolSettings();

            dim.removeFromParent();
            restartBoard();

            // If AI should start, schedule its move after aiStartDelayMs (0 => immediate).
            try {
              if (currentPlayer == aiPlayer && !gameOver) {
                if (aiStartDelayMs <= 0) {
                  Future.microtask(() {
                    try {
                      aiMove();
                    } catch (_) {}
                  });
                } else {
                  Future.delayed(Duration(milliseconds: aiStartDelayMs), () {
                    try {
                      aiMove();
                    } catch (_) {}
                  });
                }
              }
            } catch (_) {}
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
    // Human should always start. Set current player to the human player's symbol
    // so that symbols can rotate but the human always gets the first move.
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
    // Build Score object and save via ScoreService (server call or local fallback).
    String playerId = loggedInUser.id;
    bool loggedIn = playerId.isNotEmpty;
    if (!loggedIn) {
      playerId = await GuestService.getOrCreateGuestId();
    }

    final score = Score(
      playerId: playerId,
      playerName: loggedInUser.userName.isNotEmpty
          ? loggedInUser.userName
          : 'Guest',
      wins: (result == 'win') ? 1 : 0,
      draws: (result == 'draw') ? 1 : 0,
      losses: (result == 'loss') ? 1 : 0,
      points: (result == 'win')
          ? 3
          : (result == 'draw')
          ? 1
          : 0,
    );

    try {
      await ScoreService().saveScore(score, loggedIn: loggedIn);
    } catch (e) {
      // ScoreService already falls back to local persistence on failures,
      // but log any unexpected errors for diagnostics.
      print('Failed to save score: $e');
    }
  }

  Future<void> applySymbolSettings() async {
    humanPlayer = humanIsX ? 'X' : 'O';
    aiPlayer = humanIsX ? 'O' : 'X';
    // Load appropriate sprites for the icons
    try {
      humanIcon.sprite =
          await (findGame()?.loadSprite(
                humanPlayer == 'X' ? 'X.png' : 'O.png',
              ) ??
              Sprite.load(humanPlayer == 'X' ? 'X.png' : 'O.png'));
      aiIcon.sprite =
          await (findGame()?.loadSprite(aiPlayer == 'X' ? 'X.png' : 'O.png') ??
              Sprite.load(aiPlayer == 'X' ? 'X.png' : 'O.png'));
    } catch (_) {}
    // Ensure the human always starts. This keeps symbol rotation (humanIsX)
    // but guarantees the human is the first to move each round.
    currentPlayer = humanPlayer;
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
      sprite:
          await (findGame()?.loadSprite(player == 'X' ? 'X.png' : 'O.png') ??
              Sprite.load(player == 'X' ? 'X.png' : 'O.png')),
      size: Vector2(70, 70),
      anchor: Anchor.center,
      position: size / 2,
    );
    add(markSprite!);
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
  Future<void> onLoad() async => sprite =
      await (findGame()?.loadSprite(imagePath) ?? Sprite.load(imagePath));

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
