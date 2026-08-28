import 'dart:async';
// dart:convert not required here
import 'dart:math';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/effects.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flame_audio/flame_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tictactoe_game/confirmation_overlay.dart';
import 'package:tictactoe_game/end_match_overlay.dart';
import 'package:tictactoe_game/components/ornate_overlay_panel.dart';
import 'package:tictactoe_game/settings_screen.dart';
import 'package:tictactoe_game/board_layout.dart';
import 'package:tictactoe_game/components/button.dart';
import 'package:tictactoe_game/game_themes/theme.dart';
import 'package:tictactoe_game/game_themes/theme_board.dart';
import 'package:tictactoe_game/game_themes/theme_store.dart';
import 'ai.dart';
import 'models/user.dart' as app_user;
import 'service/guest_service.dart';
import 'service/score_service.dart';
import 'models/score.dart';
import 'vs_computer_match_config.dart';
import 'tic_tac_toe_rules.dart';

class WinningLineComponent extends PositionComponent {
  final Vector2 start;
  final Vector2 end;
  final Color color;

  WinningLineComponent({
    required this.start,
    required this.end,
    required this.color,
  }) : super(priority: 2000);

  @override
  void render(Canvas canvas) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.95)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(start.x, start.y),
      Offset(end.x, end.y),
      paint,
    );
    super.render(canvas);
  }
}

class TicTacToeVsAI extends Component {
  final VsComputerMatchConfig config;

  String humanPlayer = 'X';
  String aiPlayer = 'O';
  String currentPlayer = 'X';
  bool humanIsX = true;
  bool gameOver = false;

  late final BoardLayout layout;
  bool _boardReady = false;
  app_user.User loggedInUser;

  late TicTacToeAI ai;
  late TextComponent scoreText;
  late SpriteComponent humanIcon;
  late SpriteComponent aiIcon;
  late TextComponent matchText;

  int currentRound = 1;
  int humanWins = 0;
  int aiWins = 0;
  int draws = 0;
  bool confettiRunning = false;
  final Random random = Random();
  final List<Component> confettiPieces = [];
  // A relaxed match gives the player a little more time between moves.
  int get aiReactionDelayMs => config.difficulty == 1 ? 650 : 450;

  int get aiLevel => config.difficulty == 1
      ? 1
      : config.difficulty == 2
      ? 10
      : 50;

  // Active theme (symbols + skin) read from the sync global cache.
  GameTheme theme = ThemeStore.current;
  bool _themeDirty = false;
  RectangleComponent? _background;
  final List<Component> _themeBoardComponents = [];
  final List<ButtonComponent> _themeButtons = [];

  // Store references to current overlay components so onHome can clean them up
  EndMatchOverlay? currentEndMatchOverlay;
  InputBlockingDim? currentDimOverlay;

  late List<List<String>> board;

  @override
  void onMount() {
    super.onMount();
    if (theme.id != ThemeStore.current.id) {
      theme = ThemeStore.current;
      _refreshTheme();
    }
  }

  @override
  void onRemove() {
    super.onRemove();
  }

  bool get themeNeedsRefresh => _themeDirty;

  void _onThemeChanged() {
    if (theme.id == ThemeStore.current.id) return;
    _themeDirty = true;
    theme = ThemeStore.current;
    _refreshTheme();
  }

  Future<void> _refreshTheme() async {
    if (_background == null) return;
    _themeDirty = false;
    _background!.paint.color = theme.boardBackground;
    for (final component in _themeBoardComponents) {
      component.removeFromParent();
    }
    _themeBoardComponents
      ..clear()
      ..addAll(themedBoardComponents(layout, theme));
    for (final component in _themeBoardComponents) {
      add(component);
    }
    for (final button in _themeButtons) {
      button.updateTheme(theme);
    }
    try {
      await applySymbolSettings();
      for (final cell in children.whereType<TicTacToeCell>()) {
        final player = board[cell.row][cell.col];
        if (player.isNotEmpty) cell.mark(player);
      }
    } catch (_) {}
  }

  TicTacToeVsAI({VsComputerMatchConfig? config, app_user.User? loggedInUser})
    : config =
          config ??
          const VsComputerMatchConfig(
            difficulty: 2,
            rounds: 1,
            humanPlayer: 'X',
          ),
      humanIsX = (config?.humanPlayer ?? 'X') == 'X',
      humanPlayer = config?.humanPlayer ?? 'X',
      aiPlayer = (config?.humanPlayer ?? 'X') == 'X' ? 'O' : 'X',
      currentPlayer = config?.humanPlayer ?? 'X',
      loggedInUser =
          loggedInUser ??
          app_user.User(
            id: '',
            userName: 'Guest',
            providerId: '',
            providerName: '',
          );
  @override
  bool containsLocalPoint(Vector2 point) => true;

  @override
  void onTapDown(TapDownEvent event) {
    if (!_boardReady || board.isEmpty) return;
    final point = event.localPosition;
    final boardRight = layout.boardX + layout.cellWidth * config.gridSize;
    final boardBottom = layout.boardY + layout.cellHeight * config.gridSize;
    if (point.x < layout.boardX ||
        point.x >= boardRight ||
        point.y < layout.boardY ||
        point.y >= boardBottom) {
      return;
    }
    final col = ((point.x - layout.boardX) / layout.cellWidth).floor();
    final row = ((point.y - layout.boardY) / layout.cellHeight).floor();
    handleTap(row, col);
    event.continuePropagation = false;
  }

  @override
  Future<void> onLoad() async {
    currentPlayer = humanPlayer;
    ai = TicTacToeAI();
    final canvasSize = findGame()?.size ?? BoardLayout.defaultScreenSize;
    layout = BoardLayout(canvasSize, gridSize: config.gridSize);
    board = List.generate(
      config.gridSize,
      (_) => List.filled(config.gridSize, ''),
    );
    _boardReady = true;

    theme = ThemeStore.current;

    // Background + board (themed solid + themed grid)
    _background = RectangleComponent(
      size: canvasSize,
      position: Vector2.zero(),
      paint: Paint()..color = theme.boardBackground,
    );
    add(_background!);
    _themeBoardComponents.addAll(themedBoardComponents(layout, theme));
    for (final piece in _themeBoardComponents) {
      add(piece);
    }

    try {
      // Header icons stay readable while the board cells scale for larger grids.
      final iconSize = min(canvasSize.x * 0.14, 50.0);
      // Position icons at 25% down from screen top (well above the board)
      final topBarY = canvasSize.y * 0.15;
      final iconMargin = max(iconSize / 2 + 12, canvasSize.x * 0.14);
      final leftIconX = iconMargin;
      final rightIconX = canvasSize.x - iconMargin;
      final centerX = canvasSize.x / 2;

      humanIcon = SpriteComponent()
        ..size = Vector2(iconSize, iconSize)
        ..position = Vector2(leftIconX, topBarY)
        ..anchor = Anchor.center;
      add(humanIcon);
      aiIcon = SpriteComponent()
        ..size = Vector2(iconSize, iconSize)
        ..position = Vector2(rightIconX, topBarY)
        ..anchor = Anchor.center;
      add(aiIcon);

      matchText = TextComponent(
        text: 'ROUND 1 OF ${config.rounds}',
        position: Vector2(centerX, topBarY + iconSize * 0.95),
        anchor: Anchor.center,
        textRenderer: TextPaint(
          style: TextStyle(
            fontSize: 17,
            color: theme.gridColor,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
      add(matchText);

      scoreText = TextComponent(
        text: 'YOU 0  -  COMPUTER 0',
        position: Vector2(centerX, topBarY + iconSize * 1.55),
        anchor: Anchor.center,
        textRenderer: TextPaint(
          style: TextStyle(
            fontSize: 15,
            color: theme.contrastColor,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
      add(scoreText);
    } catch (e) {
      add(
        TextComponent(
          text: 'Error loading VS Computer screen.',
          position: Vector2(canvasSize.x / 2, canvasSize.y / 2),
          anchor: Anchor.center,
          textRenderer: TextPaint(
            style: const TextStyle(fontSize: 24, color: Colors.redAccent),
          ),
        ),
      );
    }

    // Apply the character selected for this match.
    humanIsX = config.humanPlayer == 'X';
    currentPlayer = humanPlayer;
    await applySymbolSettings();

    // Place the settings icon at the top-right corner.
    final topButtonY = canvasSize.y * 0.06;
    add(
      SettingsIconButton(
        position: Vector2(canvasSize.x - 32, topButtonY),
        size: Vector2(36, 36),
        onPressed: () {
          final flameGame = findGame();
          if (flameGame != null) {
            (flameGame as dynamic).openSettings(returnRoute: 'vsai_active');
          }
        },
      ),
    );

    // Restart button at bottom center (repeats current level)
    final backButton = ButtonComponent(
      label: 'RESTART',
      position: Vector2(canvasSize.x / 2, canvasSize.y - 46),
      size: Vector2(120, 40),
      theme: theme,
      onPressed: () {
        // Restart the current round without changing match settings.
        restartBoard();
      },
    );
    _themeButtons.add(backButton);
    add(backButton);

    // Back button
    final restartButton = ButtonComponent(
      label: 'BACK',
      position: Vector2(70, canvasSize.y - 46),
      size: Vector2(72, 34),
      theme: theme,
      onPressed: () async {
        final flameGame = findGame();
        if (flameGame == null) return;

        final dim = InputBlockingDim(
          size: flameGame.size,
          color: Colors.black.withValues(alpha: 0.6),
          priority: 1000000000000,
        );
        flameGame.add(dim);

        late ConfirmationOverlay overlay;
        overlay = ConfirmationOverlay(
          theme: theme,
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
    );
    _themeButtons.add(restartButton);
    add(restartButton);

    // Board cells
    for (int row = 0; row < config.gridSize; row++) {
      for (int col = 0; col < config.gridSize; col++) {
        add(
          TicTacToeCell(
            row: row,
            col: col,
            position: Vector2(
              layout.boardX + col * layout.cellWidth,
              layout.boardY + row * layout.cellHeight,
            ),
            size: Vector2(layout.cellWidth, layout.cellHeight),
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

    if (checkForWinner(player)) {
      _showWinningLine(player);
      endRound();
    } else if (checkForDraw()) {
      endRound();
    } else {
      currentPlayer = (player == humanPlayer) ? aiPlayer : humanPlayer;
    }
  }

  void aiMove() {
    if (gameOver) return;
    final move = ai.getMoveForLevel(
      board,
      aiLevel,
      aiPlayer,
      humanPlayer,
      winLength: config.winLength,
    );
    if (move[0] != -1) makeMove(move[0], move[1], aiPlayer);
  }

  void endRound() {
    debugPrint('>>> endRound() called, gameOver=$gameOver');
    gameOver = true;
    _hideMatchHeader();
    Future.delayed(const Duration(seconds: 1), () async {
      debugPrint('>>> endRound delayed callback running');
      // Mark that the player has completed at least one match so other
      // flows (avatar claim / sign-in prompts) can trigger on first return
      // to the home screen.
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('completed_first_match', true);
      } catch (_) {}

      String result;
      if (checkForWinner(humanPlayer)) {
        result = "win";
        _startConfetti();
      } else if (checkForWinner(aiPlayer)) {
        result = "loss";
      } else {
        result = "draw";
      }

      if (result == 'win') {
        humanWins++;
      } else if (result == 'loss') {
        aiWins++;
      } else {
        draws++;
      }
      final matchComplete = currentRound >= config.rounds;
      _updateMatchHeader(matchComplete: matchComplete);

      if (matchComplete) {
        final matchResult = humanWins > aiWins
            ? 'win'
            : aiWins > humanWins
            ? 'loss'
            : 'draw';
        await saveScore(matchResult);
      }

      // Track matches towards periodic progression sign-in prompts for
      // non-signed-in users. This counter is used to show the Next
      // sign-in gate every 5 matches (5, 10, 15...). Increment it here
      // so the onNext handler can decide whether to prompt.
      try {
        final prefs2 = await SharedPreferences.getInstance();
        int c = prefs2.getInt('next_progression_matches_count') ?? 0;
        c++;
        await prefs2.setInt('next_progression_matches_count', c);
      } catch (_) {}

      debugPrint('>>> About to create EndMatchOverlay, result=$result');
      final flameGame = findGame();
      if (flameGame != null) {
        debugPrint('>>> flameGame found, size=${flameGame.size}');
        final dim = InputBlockingDim(
          size: flameGame.size,
          color: Colors.black.withValues(alpha: 0.6),
          priority: 1000000000000,
        );
        debugPrint('>>> Adding dim overlay to flameGame');
        flameGame.add(dim);
        currentDimOverlay = dim;

        final overlay = EndMatchOverlay(
          theme: theme,
          didWin: result == "win",
          didDraw: result == "draw",
          scoreline: 'YOU $humanWins  -  COMPUTER $aiWins',
          showSignInPrompt: false,
          singleHomeButton: matchComplete,
          onRestart: () {
            dim.removeFromParent();
            restartBoard();
            _showMatchHeader();
          },
          onNext: () {
            currentRound++;
            dim.removeFromParent();
            restartBoard();
            _updateMatchHeader();
            _showMatchHeader();
          },
          onHome: () {
            debugPrint('>>> onHome pressed!');
            // When the player presses Home, navigate back to menu. If the
            // player has completed their first match and has not yet been
            // offered an avatar, navigate to profile screen the first time
            // they return home so they can pick an avatar.
            // Ensure any confetti or sound-producing state is stopped.
            try {
              confettiRunning = false;
            } catch (_) {}
            try {
              for (var c in List.from(confettiPieces)) {
                try {
                  c.removeFromParent();
                } catch (_) {}
              }
            } catch (_) {}
            try {
              confettiPieces.clear();
            } catch (_) {}

            try {
              currentDimOverlay?.removeFromParent();
            } catch (_) {}
            try {
              currentEndMatchOverlay?.removeFromParent();
            } catch (_) {}
            restartBoard();
            final router = (findGame() as dynamic).router;

            // Always return to the Home screen after leaving a match.
            Future(() async {
              try {
                router?.pushNamed('menu');
              } catch (e) {
                debugPrint('onHome: exception checking prefs: $e');
                router?.pushNamed('menu');
              }
            });
          },
        );

        overlay.priority = 1000000000001;
        debugPrint(
          '>>> EndMatchOverlay created: didWin=${result == "win"}, didDraw=${result == "draw"}',
        );
        flameGame.add(overlay);
        currentEndMatchOverlay = overlay;
        debugPrint('>>> EndMatchOverlay successfully added to flameGame');
      }
    });
  }

  void _updateMatchHeader({bool matchComplete = false}) {
    matchText.text = matchComplete
        ? 'MATCH COMPLETE'
        : 'ROUND $currentRound OF ${config.rounds}';
    scoreText.text = 'YOU $humanWins  -  COMPUTER $aiWins';
  }

  void _showWinningLine(String player) {
    final line = TicTacToeRules.winningLine(board, config.gridSize, player);
    if (line == null) return;
    add(
      WinningLineComponent(
        start: Vector2(
          layout.boardX + (line[1] + 0.5) * layout.cellWidth,
          layout.boardY + (line[0] + 0.5) * layout.cellHeight,
        ),
        end: Vector2(
          layout.boardX + (line[3] + 0.5) * layout.cellWidth,
          layout.boardY + (line[2] + 0.5) * layout.cellHeight,
        ),
        color: player == 'X' ? theme.xColor : theme.oColor,
      ),
    );
  }

  void _hideMatchHeader() {
    matchText.removeFromParent();
    scoreText.removeFromParent();
  }

  void _showMatchHeader() {
    if (!matchText.isMounted) add(matchText);
    if (!scoreText.isMounted) add(scoreText);
  }

  void restartBoard() {
    board = List.generate(
      config.gridSize,
      (_) => List.filled(config.gridSize, ''),
    );
    gameOver = false;
    // Human should always start. Set current player to the human player's symbol
    // so that symbols can rotate but the human always gets the first move.
    currentPlayer = humanPlayer;

    for (var cell in children.whereType<TicTacToeCell>()) {
      cell.markSprite?.removeFromParent();
      cell.markSprite = null;
    }
    for (final line in children.whereType<WinningLineComponent>().toList()) {
      line.removeFromParent();
    }

    confettiRunning = false;
    for (var c in List.from(confettiPieces)) {
      c.removeFromParent();
    }
    confettiPieces.clear();
  }

  bool checkForWinner(String player) =>
      TicTacToeRules.checkGameStatus(board, config.gridSize) == player;

  bool checkForDraw() =>
      board.every((row) => row.every((cell) => cell.isNotEmpty));

  void _startConfetti() {
    if (confettiRunning) return;
    confettiRunning = true;
    final size =
        findGame()?.size ?? Vector2(layout.screenSize.x, layout.screenSize.y);

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
      await ScoreService().saveScore(
        score,
        loggedIn: loggedIn,
        boardSize: config.gridSize,
        opponentType: 'computer',
      );
    } catch (e) {
      // ScoreService already falls back to local persistence on failures,
      // but log any unexpected errors for diagnostics.
      print('Failed to save score: $e');
    }
  }

  Future<void> applySymbolSettings() async {
    humanPlayer = humanIsX ? 'X' : 'O';
    aiPlayer = humanIsX ? 'O' : 'X';
    // Render themed symbol sprites for the header icons
    try {
      humanIcon.sprite = await theme.symbolSprite(
        humanPlayer,
        humanIcon.size.x,
        pixelRatio: 4,
      );
      aiIcon.sprite = await theme.symbolSprite(
        aiPlayer,
        aiIcon.size.x,
        pixelRatio: 4,
      );
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
  }) {
    priority = 1000;
  }

  final int row;
  final int col;
  SpriteComponent? markSprite;

  @override
  void onTapDown(TapDownEvent event) {
    if (parent is TicTacToeVsAI) {
      final vs = parent as TicTacToeVsAI;
      if (SettingsScreen.buttonSoundOn) FlameAudio.play('tap.wav');
      vs.handleTap(row, col);
      event.continuePropagation = false;
    }
  }

  void mark(String player) async {
    markSprite?.removeFromParent();
    final markSize = Vector2.all(min(size.x, size.y) * 0.75);
    final board = parent as TicTacToeVsAI;
    markSprite = SpriteComponent(
      sprite: await board.theme.symbolSprite(player, markSize.x, pixelRatio: 4),
      size: markSize,
      anchor: Anchor.center,
      position: size / 2,
    );
    add(markSprite!);
  }

  @override
  bool containsLocalPoint(Vector2 point) {
    return point.x >= 0 &&
        point.x <= size.x &&
        point.y >= 0 &&
        point.y <= size.y;
  }
}
