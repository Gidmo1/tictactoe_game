// ignore_for_file: dead_code

import 'dart:async';
import 'dart:math';
import 'service/supabase_compat.dart';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/effects.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tictactoe_game/end_match_overlay.dart';
import 'package:tictactoe_game/game_themes/theme_store.dart';
import 'components/auth_gate_component.dart';
import 'package:flame_audio/flame_audio.dart';
import 'package:tictactoe_game/settings_screen.dart';
import 'package:tictactoe_game/board_layout.dart';
import 'game_themes/theme.dart';
import 'service/supabase_compat.dart' as fb;
import 'service/competition_service.dart';
import 'service/score_service.dart';
import 'models/score.dart';
import 'service/supabase_match_service.dart';
import 'tictactoe.dart';
import 'service/guest_service.dart';
import 'components/ornate_overlay_panel.dart';

class TicTacToeInviteScreen extends Component {
  final String matchId;
  late List<String> board;
  String playerXUID = '';
  String playerOUID = '';
  bool gameOver = false;
  late String currentPlayer;
  late TextComponent messageText;
  late TextComponent playerXNameText;
  late TextComponent playerONameText;
  SpriteComponent? playerXSymbolSprite;
  SpriteComponent? playerOSymbolSprite;
  SpriteComponent? playerXFlagSprite;
  SpriteComponent? playerOFlagSprite;
  Sprite? smallXSprite;
  Sprite? smallOSprite;
  // removed per-lobby found message; lobby now shows the 'Found opponent' notice

  late final BoardLayout layout;

  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  final FirebaseFunctions functions = FirebaseFunctions.instanceFor(
    region: 'us-central1',
  );
  StreamSubscription<DocumentSnapshot>? matchSubscription;
  StreamSubscription<Map<String, dynamic>>? supabaseMatchSubscription;

  bool confettiRunning = false;
  final Random random = Random();
  final List<Component> confettiPieces = [];
  bool _addedReturnButton = false;
  bool _moveInFlight = false;
  bool _endOverlayShown = false;
  bool _scoreRecorded = false;
  bool _matchReady = false;
  _WinningLine? _winningLine;
  TextComponent? _inviteCodeText;
  late TextComponent _xScoreText;
  late TextComponent _scoreValueText;
  late TextComponent _oScoreText;
  _MatchLoadingModal? _loading;

  TicTacToeInviteScreen({required this.matchId});

  @override
  Future<void> onLoad() async {
    board = List.filled(9, '');
    currentPlayer = 'X';

    final canvasSize = findGame()?.size ?? BoardLayout.defaultScreenSize;
    layout = BoardLayout(canvasSize);

    final background = RectangleComponent(
      size: canvasSize,
      position: Vector2.zero(),
      paint: Paint()..color = ThemeStore.current.boardBackground,
    )..priority = -2;
    add(background);

    final inviteGame = findGame();
    final inviteCode = inviteGame is TicTacToeGame
      ? inviteGame.pendingInviteCode
      : null;
    add(_InviteBoardGrid(layout: layout, theme: ThemeStore.current));
    _loading = _MatchLoadingModal(
      size: canvasSize,
      theme: ThemeStore.current,
      inviteCode: inviteCode,
    )..priority = 100;
    add(_loading!);

    // Message text
    final titleY = layout.boardY - layout.cellHeight * 0.5;
    messageText = TextComponent(
      text: "Waiting for opponent...",
      position: Vector2(canvasSize.x / 2, titleY),
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

    _xScoreText = TextComponent(
      text: 'X',
      position: Vector2(canvasSize.x / 2 - 76, 104),
      anchor: Anchor.centerRight,
      textRenderer: TextPaint(
        style: TextStyle(
          color: ThemeStore.current.xColor,
          fontSize: 34,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
    _scoreValueText = TextComponent(
      text: '0  -  0',
      position: Vector2(canvasSize.x / 2, 104),
      anchor: Anchor.center,
      textRenderer: TextPaint(
        style: TextStyle(
          color: ThemeStore.current.textColor,
          fontSize: 25,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
    _oScoreText = TextComponent(
      text: 'O',
      position: Vector2(canvasSize.x / 2 + 76, 104),
      anchor: Anchor.centerLeft,
      textRenderer: TextPaint(
        style: TextStyle(
          color: ThemeStore.current.oColor,
          fontSize: 34,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
    add(_xScoreText);
    add(_scoreValueText);
    add(_oScoreText);

    final topPadding = max(layout.boardY * 0.06, 32.0);
    final nameFontSize = layout.screenSize.x * 0.04;
    final iconSize = layout.screenSize.x * 0.078;
    final leftNameX = layout.boardX + 10;
    final rightNameX = canvasSize.x - layout.boardX - 10;

    // Player name placeholders (left and right)
    playerXNameText = TextComponent(
      text: '',
      position: Vector2(leftNameX, topPadding),
      anchor: Anchor.topLeft,
      textRenderer: TextPaint(
        style: TextStyle(
          fontSize: nameFontSize,
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
      ),
    )..priority = 10010;
    add(playerXNameText);

    playerONameText = TextComponent(
      text: '',
      position: Vector2(rightNameX, topPadding),
      anchor: Anchor.topRight,
      textRenderer: TextPaint(
        style: TextStyle(
          fontSize: nameFontSize,
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
      ),
    )..priority = 10010;
    add(playerONameText);

    // Load small symbol icons next to names
    try {
      smallXSprite =
          await (findGame()?.loadSprite('X.png') ?? Sprite.load('X.png'));
      playerXSymbolSprite = SpriteComponent(
        sprite: smallXSprite,
        size: Vector2(iconSize, iconSize),
        position: Vector2(leftNameX + iconSize * 0.5, topPadding + nameFontSize * 1.1),
        anchor: Anchor.topLeft,
      )..priority = 10011;
      add(playerXSymbolSprite!);
    } catch (_) {}

    try {
      smallOSprite =
          await (findGame()?.loadSprite('O.png') ?? Sprite.load('O.png'));
      playerOSymbolSprite = SpriteComponent(
        sprite: smallOSprite,
        size: Vector2(iconSize, iconSize),
        position: Vector2(rightNameX - iconSize * 1.5, topPadding + nameFontSize * 1.1),
        anchor: Anchor.topLeft,
      )..priority = 10011;
      add(playerOSymbolSprite!);
    } catch (_) {}

    // Board cells
    for (int row = 0; row < 3; row++) {
      for (int col = 0; col < 3; col++) {
        add(
          TicTacToeCellInvite(
            row: row,
            col: col,
            position: Vector2(
              layout.boardX + col * layout.cellWidth,
              layout.boardY + row * layout.cellHeight,
            ),
            size: Vector2(layout.cellWidth, layout.cellHeight),
            parentBoard: this,
          ),
        );
      }
    }

    await _startSupabaseMatch();
    return;

    // Firestore listener for match updates
    // Choose collection based on whether the pending match is a tournament
    final gameRef = findGame();
    final collectionName =
        (gameRef != null &&
            (gameRef as dynamic).pendingMatchIsTournament == true)
        ? 'tournamentMatches'
        : 'matches';

    matchSubscription = firestore
        .collection(collectionName)
        .doc(matchId)
        .snapshots()
        .listen(
          (snapshot) {
            final data = snapshot.data();
            if (data == null) return;

            // Add return button only for non-tournament matches
            if (data['tournament'] != true && !_addedReturnButton) {
              final buttonSize = layout.cellHeight * 0.45;
              add(
                _PressdownButton(
                  imagePath: 'return.png',
                  position: Vector2(layout.boardX + buttonSize, layout.boardY - buttonSize * 1.5),
                  size: Vector2(buttonSize, buttonSize),
                  onPressed: leaveMatch,
                ),
              );
              _addedReturnButton = true;
            }

            final boardData1D = List<String>.from(data['board']);
            // store player ids for mapping board values to X/O
            playerXUID = (data['playerXUID'] ?? '') as String;
            playerOUID = (data['playerOUID'] ?? '') as String;

            // Update displayed player names if available. Support nested player objects
            try {
              final px = data['playerX'] as Map<String, dynamic>?;
              final po = data['playerO'] as Map<String, dynamic>?;
              String pxName = '';
              String poName = '';
              Map<String, dynamic>? pxProfile;
              Map<String, dynamic>? poProfile;
              if (px != null) {
                pxName = (px['displayName'] ?? px['name'] ?? '') as String;
              }
              if (po != null) {
                poName = (po['displayName'] ?? po['name'] ?? '') as String;
              }
              // Prefer persisted profile info if server provided an AI profile
              try {
                pxProfile = data['playerXProfile'] as Map<String, dynamic>?;
                poProfile = data['playerOProfile'] as Map<String, dynamic>?;
                if (pxProfile != null &&
                    (pxProfile['name'] ?? '').toString().isNotEmpty) {
                  pxName = pxProfile['name'] as String;
                }
                if (poProfile != null &&
                    (poProfile['name'] ?? '').toString().isNotEmpty) {
                  poName = poProfile['name'] as String;
                }
              } catch (_) {}
              // fallback to simple fields
              if (pxName.isEmpty) {
                pxName = (data['playerXName'] ?? '') as String;
              }
              if (poName.isEmpty) {
                poName = (data['playerOName'] ?? '') as String;
              }
              if (pxName.isEmpty) {
                pxName = playerXUID.isNotEmpty ? playerXUID : 'Player X';
              }
              if (poName.isEmpty) {
                poName = playerOUID.isNotEmpty ? playerOUID : 'Player O';
              }

              // Strip any trailing country in parentheses if present (we show
              // country via a flag icon instead).
              try {
                pxName = pxName.replaceAll(RegExp(r"\s*\(.*\)\s*"), '');
                poName = poName.replaceAll(RegExp(r"\s*\(.*\)\s*"), '');
              } catch (_) {}

              // Display left = current player, right = opponent
              final flameGame = findGame();
              final myUID = fb.FirebaseAuth.instance.currentUser?.uid ?? '';
              if (myUID.isEmpty &&
                  flameGame != null &&
                  (flameGame as dynamic).myPlayerSymbol != null) {
                // If guest, use the local symbol assignment to decide left/right
                final mySym = (flameGame as dynamic).myPlayerSymbol as String?;
                if (mySym == 'X') {
                  playerXNameText.text = pxName;
                  playerONameText.text = poName;
                  // left is X
                  if (playerXSymbolSprite != null && smallXSprite != null) {
                    playerXSymbolSprite!.sprite = smallXSprite;
                  }
                  if (playerOSymbolSprite != null && smallOSprite != null) {
                    playerOSymbolSprite!.sprite = smallOSprite;
                  }
                } else {
                  playerXNameText.text = poName;
                  playerONameText.text = pxName;
                  if (playerXSymbolSprite != null && smallOSprite != null) {
                    playerXSymbolSprite!.sprite = smallOSprite;
                  }
                  if (playerOSymbolSprite != null && smallXSprite != null) {
                    playerOSymbolSprite!.sprite = smallXSprite;
                  }
                }
              } else {
                if (myUID == playerXUID) {
                  playerXNameText.text = pxName;
                  playerONameText.text = poName;
                  if (playerXSymbolSprite != null && smallXSprite != null){
                    playerXSymbolSprite!.sprite = smallXSprite;
                  }
                  if (playerOSymbolSprite != null && smallOSprite != null){
                  }
                    playerOSymbolSprite!.sprite = smallOSprite;
                } else {
                  playerXNameText.text = poName;
                  playerONameText.text = pxName;
                  if (playerXSymbolSprite != null && smallOSprite != null){
                    playerXSymbolSprite!.sprite = smallOSprite;
                  }
                  if (playerOSymbolSprite != null && smallXSprite != null){
                    playerOSymbolSprite!.sprite = smallXSprite;
                  }
                }
              }

              // Load and show country flag icons if profile country available.
              Future.microtask(() async {
                try {
                  // Determine which profile corresponds to the left and right
                  // name entries so we can render the correct flag beside them.
                  final flame = findGame();
                  final leftIsX = (() {
                    try {
                      if (flame == null) return true;
                      final sym = (flame as dynamic).myPlayerSymbol as String?;
                      if (sym == null) return true;
                      // left side corresponds to 'X' in our UI layout
                      return sym == 'X';
                    } catch (_) {
                      return true;
                    }
                  })();

                  // choose profiles for left/right based on leftIsX and who is X in match
                  Map<String, dynamic>? leftProfile;
                  Map<String, dynamic>? rightProfile;
                  if (leftIsX) {
                    leftProfile = pxProfile;
                    rightProfile = poProfile;
                  } else {
                    leftProfile = poProfile;
                    rightProfile = pxProfile;
                  }

                  // Helper to create/update a flag sprite for a side
                  Future<void> ensureFlag(
                    bool isLeft,
                    Map<String, dynamic>? profile,
                  ) async {
                    try {
                      final country =
                          (profile != null ? (profile['country'] ?? '') : '')
                              ?.toString() ??
                          '';
                      final key = country.toLowerCase().replaceAll(
                        RegExp('[^a-z0-9]'),
                        '_',
                      );
                      if (country.isEmpty) {
                        // remove existing flag for this side
                        if (isLeft) {
                          try {
                            playerXFlagSprite?.removeFromParent();
                          } catch (_) {}
                          playerXFlagSprite = null;
                        } else {
                          try {
                            playerOFlagSprite?.removeFromParent();
                          } catch (_) {}
                          playerOFlagSprite = null;
                        }
                        return;
                      }

                      final path = 'flags/$key.png';
                      Sprite? sp;
                      try {
                        sp =
                            await (findGame()?.loadSprite(path) ??
                                Sprite.load(path));
                      } catch (_) {
                        sp = null;
                      }
                      if (sp != null) {
                        final flagWidth = layout.screenSize.x * 0.08;
                        final flagHeight = layout.screenSize.y * 0.03;
                        final flagTop = topPadding + nameFontSize * 1.1 + 4;
                        if (isLeft) {
                          if (playerXFlagSprite == null) {
                            playerXFlagSprite = SpriteComponent(
                              sprite: sp,
                              size: Vector2(flagWidth, flagHeight),
                              position: Vector2(leftNameX + flagWidth * 0.5, flagTop),
                              anchor: Anchor.centerLeft,
                            )..priority = 10012;
                            add(playerXFlagSprite!);
                          } else {
                            playerXFlagSprite!
                              ..sprite = sp
                              ..size = Vector2(flagWidth, flagHeight)
                              ..position = Vector2(leftNameX + flagWidth * 0.5, flagTop);
                          }
                        } else {
                          if (playerOFlagSprite == null) {
                            playerOFlagSprite = SpriteComponent(
                              sprite: sp,
                              size: Vector2(flagWidth, flagHeight),
                              position: Vector2(rightNameX - flagWidth * 0.5, flagTop),
                              anchor: Anchor.centerRight,
                            )..priority = 10012;
                            add(playerOFlagSprite!);
                          } else {
                            playerOFlagSprite!
                              ..sprite = sp
                              ..size = Vector2(flagWidth, flagHeight)
                              ..position = Vector2(rightNameX - flagWidth * 0.5, flagTop);
                          }
                        }
                      } else {
                        if (isLeft) {
                          try {
                            playerXFlagSprite?.removeFromParent();
                          } catch (_) {}
                          playerXFlagSprite = null;
                        } else {
                          try {
                            playerOFlagSprite?.removeFromParent();
                          } catch (_) {}
                          playerOFlagSprite = null;
                        }
                      }
                    } catch (_) {}
                  }

                  await ensureFlag(true, leftProfile);
                  await ensureFlag(false, rightProfile);
                } catch (_) {}
              });
            } catch (_) {}
            for (int i = 0; i < 9; i++) {
              if (board[i] != boardData1D[i]) {
                board[i] = boardData1D[i];
                final r = i ~/ 3;
                final c = i % 3;
                final cell = children
                    .whereType<TicTacToeCellInvite>()
                    .firstWhere((cell) => cell.row == r && cell.col == c);
                if (board[i] != '') cell.mark(board[i]);
              }
            }

            currentPlayer = data['currentTurn'] ?? 'X';
            // Infer gameOver locally if server lags or if the board is full.
            final winnerUID = (data['winnerUID'] ?? '') as String? ?? '';
            final serverGameOver = data['gameOver'] ?? false;
            final boardFull = board.every((cell) => cell.isNotEmpty);
            gameOver = serverGameOver || winnerUID.isNotEmpty || boardFull;

            // 'Found' notification is shown in the FriendLobby before routing.

            if (gameOver) {
              final fb.User? firebaseUser =
                  fb.FirebaseAuth.instance.currentUser;
              final myUID = firebaseUser?.uid ?? '';
              final overlayMessage = winnerUID == ''
                  ? 'Draw!'
                  : (winnerUID == myUID ? 'You win!' : 'You lose!');
              // Cancel any pending AI scheduling so client won't trigger further moves (AI removed)
              messageText.text = overlayMessage;
              _startConfetti();

              // Show a dim background and end-match overlay (prompt sign-in after first match)
              try {
                final flameGame = findGame();
                if (flameGame != null) {
                  // Attach dim + EndMatchOverlay robustly with retries.
                  _addEndMatchOverlaySafely(
                    flameGame,
                    didWin: (winnerUID == myUID),
                    didDraw: (winnerUID == ''),
                    overrideMessage: overlayMessage,
                  );
                }
              } catch (_) {}

              // For tournament matches, submit results via dedicated callable.
              try {
                final isTournament = data['tournament'] == true;
                final tournamentId = data['tournamentId'] as String?;
                if (isTournament &&
                    tournamentId != null &&
                    winnerUID.isNotEmpty) {
                  // fire-and-forget; server will validate and award points
                  ScoreService()
                      .submitTournamentResult(
                        tournamentId: tournamentId,
                        matchId: matchId,
                        winnerId: winnerUID,
                      )
                      .catchError((e) {
                        debugPrint('submitTournamentResult failed: $e');
                      });
                  // Also trigger competition leaderboard callable as a best-effort refresh.
                  try {
                    final players = List<String>.from(data['players'] ?? []);
                    // If players array missing, fall back to explicit fields
                    if (players.isEmpty) {
                      if ((data['playerXUID'] ?? '') != ''){
                        players.add(data['playerXUID']);
                      }
                      if ((data['playerOUID'] ?? '') != '') {
                        players.add(data['playerOUID']);
                      }
                    }
                    // Award results: winner -> win, others -> loss; draw -> draw for all
                    if (winnerUID == '') {
                      for (final p in players.where((p) => p != '')) {
                        ScoreService().submitCompetitionScore(
                          playerId: p,
                          result: 'draw',
                        );
                      }
                    } else {
                      for (final p in players.where((p) => p != '')) {
                        if (p == winnerUID) {
                          ScoreService().submitCompetitionScore(
                            playerId: p,
                            result: 'win',
                          );
                        } else {
                          ScoreService().submitCompetitionScore(
                            playerId: p,
                            result: 'loss',
                          );
                        }
                      }
                    }
                  } catch (e) {
                    debugPrint('Competition callable fire failed: $e');
                  }
                }
                // For non-tournament matches, submit a local score as a best-effort fallback.
                if (!isTournament) {
                  Future.microtask(() async {
                    try {
                      final fb.User? u = fb.FirebaseAuth.instance.currentUser;
                      String playerId = u?.uid ?? '';
                      if (playerId.isEmpty) {
                        playerId = await GuestService.getOrCreateGuestId();
                      }
                      final resultStr = winnerUID == ''
                          ? 'draw'
                          : (winnerUID == playerId ? 'win' : 'loss');
                      final score = Score(
                        playerId: playerId,
                        playerName: u?.displayName ?? 'Guest',
                        wins: (resultStr == 'win') ? 1 : 0,
                        draws: (resultStr == 'draw') ? 1 : 0,
                        losses: (resultStr == 'loss') ? 1 : 0,
                        points: (resultStr == 'win')
                            ? 3
                            : (resultStr == 'draw')
                            ? 1
                            : 0,
                      );
                      await ScoreService().saveScore(
                        score,
                        loggedIn: u != null,
                      );
                      try {
                        final funcs = FirebaseFunctions.instanceFor(
                          region: 'us-central1',
                        );
                        funcs
                            .httpsCallable('getLeaderboard')
                            .call({'limit': 10})
                            .then((_) {})
                            .catchError((_) {});
                      } catch (_) {}
                    } catch (e) {
                      debugPrint('Fallback score save failed: $e');
                    }
                  });
                }
              } catch (_) {}

              // Server-side trigger will handle awarding XP and marking scores.
              // The client should not write score documents.
            } else {
              final fb.User? firebaseUser =
                  fb.FirebaseAuth.instance.currentUser;
              final myUID = firebaseUser?.uid ?? '';
              messageText.text = currentPlayer == myUID
                  ? "Your turn"
                  : "Opponent's turn";

              // AI opponent handling removed.
            }
          },
          onError: (err) {
            // Handle permission errors or network failures without crashing
            debugPrint('Match snapshot listen error: $err');
            try {
              final notice = TextComponent(
                text: 'Unable to watch match (permission). Returning...',
                position: Vector2((findGame()?.size.x ?? 360) / 2, 120),
                anchor: Anchor.center,
                textRenderer: TextPaint(
                  style: const TextStyle(color: Colors.white70),
                ),
              )..priority = 11050;
              add(notice);
              Future.delayed(const Duration(milliseconds: 1400), () {
                try {
                  notice.removeFromParent();
                } catch (_) {}
              });
            } catch (_) {}
            try {
              final flameGame = findGame();
              if (flameGame != null && flameGame is TicTacToeGame) {
                flameGame.pendingMatchId = null;
                flameGame.myPlayerSymbol = null;
                flameGame.router.pushReplacementNamed('invite_options');
              }
            } catch (_) {}
            try {
              removeFromParent();
            } catch (_) {}
          },
        );

    // Create match via Cloud Function if it doesn’t exist yet
    final doc = await firestore.collection(collectionName).doc(matchId).get();
    if (!doc.exists) {
      try {
        final callable = functions.httpsCallable('createMatch');
        // prefer authenticated uid, otherwise use a persistent guest id
        final fb.User? firebaseUser = fb.FirebaseAuth.instance.currentUser;
        final playerId =
            firebaseUser?.uid ?? await GuestService.getOrCreateGuestId();
        await callable.call({'matchId': matchId, 'playerId': playerId});
      } catch (e) {
        debugPrint("Error creating match via Cloud Function: $e");
      }
    }
  }

  // Scoring for tournament matches is handled server-side; client must not
  // write scores.

  Future<void> _startSupabaseMatch() async {
    final service = SupabaseMatchService();
    final userId = service.userId;
    if (userId == null) {
      messageText.text = 'Sign in required';
      return;
    }

    try {
      await service.reconnect(matchId);
      supabaseMatchSubscription = service.watchMatch(matchId).listen(
        _applySupabaseMatch,
        onError: (error) {
          debugPrint('Supabase match subscription error: $error');
          messageText.text = 'Connection lost. Reconnecting...';
        },
      );
    } catch (error) {
      debugPrint('Supabase match reconnect failed: $error');
      messageText.text = 'Unable to reconnect to match';
    }
  }

  void _applySupabaseMatch(Map<String, dynamic> data) {
    if (data.isEmpty) return;
    final boardData = data['board'];
    if (boardData is List) {
      final flattened = <String>[];
      for (final row in boardData) {
        if (row is List) {
          flattened.addAll(row.map((cell) => cell.toString()));
        }
      }
      if (flattened.length == board.length) {
        for (var index = 0; index < flattened.length; index++) {
          if (board[index] == flattened[index]) continue;
          board[index] = flattened[index];
          final cell = children
              .whereType<TicTacToeCellInvite>()
              .firstWhere((item) => item.row * 3 + item.col == index);
          if (board[index].isNotEmpty) cell.mark(board[index]);
        }
      }
    }

    playerXUID = (data['player_x'] ?? '').toString();
    playerOUID = (data['player_o'] ?? '').toString();
    currentPlayer = (data['current_turn'] ?? 'X').toString();
    final status = (data['status'] ?? 'waiting').toString();
    final winnerId = (data['winner'] ?? '').toString();
    gameOver = status == 'finished' || status == 'abandoned';
    final xScore = status == 'finished' && winnerId == playerXUID ? 1 : 0;
    final oScore = status == 'finished' && winnerId == playerOUID ? 1 : 0;
    _scoreValueText.text = '$xScore  -  $oScore';
    _matchReady = status == 'active' || gameOver;
    if (_matchReady) {
      _loading?.removeFromParent();
      _loading = null;
    }
    final gameRef = findGame();
    final userId = SupabaseMatchService().userId;
    final mySymbol = userId == playerXUID
        ? 'X'
        : (userId == playerOUID ? 'O' : null);
    if (gameRef is TicTacToeGame && mySymbol != null) {
      gameRef.myPlayerSymbol = mySymbol;
    }
    if (status != 'waiting') {
      _inviteCodeText?.removeFromParent();
      _inviteCodeText = null;
    }

    if (status == 'waiting') {
      messageText.text = 'Waiting for opponent...';
    } else if (gameOver) {
      final didWin = winnerId.isNotEmpty && winnerId == SupabaseMatchService().userId;
      final didDraw = winnerId.isEmpty && status == 'finished';
      messageText.text = didDraw ? 'Draw!' : (didWin ? 'You win!' : 'You lose!');
      if (winnerId.isNotEmpty) {
        _showWinningLine();
      }
      _recordOnlineScore(winnerId: winnerId, didDraw: didDraw);
      if (!_endOverlayShown) {
        _endOverlayShown = true;
        _addEndMatchOverlaySafely(
          findGame(),
          didWin: didWin,
          didDraw: didDraw,
          overrideMessage: messageText.text,
          scoreXText: 'X',
          scoreOText: 'O',
          scoreline: '$xScore  -  $oScore',
          scoreXColor: ThemeStore.current.xColor,
          scoreOColor: ThemeStore.current.oColor,
        );

      }
    } else {
      messageText.text = currentPlayer == mySymbol
          ? 'Your turn'
          : 'Opponent\'s turn';
    }
  }

  void _showWinningLine() {
    if (_winningLine != null) return;
    const winningPatterns = [
      [0, 1, 2],
      [3, 4, 5],
      [6, 7, 8],
      [0, 3, 6],
      [1, 4, 7],
      [2, 5, 8],
      [0, 4, 8],
      [2, 4, 6],
    ];
    for (final pattern in winningPatterns) {
      if (board[pattern[0]].isNotEmpty &&
          board[pattern[0]] == board[pattern[1]] &&
          board[pattern[1]] == board[pattern[2]]) {
        _winningLine = _WinningLine(
          start: _cellCenter(pattern[0]),
          end: _cellCenter(pattern[2]),
          color: board[pattern[0]] == 'X'
              ? ThemeStore.current.xColor
              : ThemeStore.current.oColor,
        );
        add(_winningLine!);
        return;
      }
    }
  }

  Vector2 _cellCenter(int index) => Vector2(
    layout.boardX + (index % 3 + 0.5) * layout.cellWidth,
    layout.boardY + (index ~/ 3 + 0.5) * layout.cellHeight,
  );

  Future<void> _recordOnlineScore({
    required String winnerId,
    required bool didDraw,
  }) async {
    if (_scoreRecorded) return;
    final userId = SupabaseMatchService().userId;
    if (userId == null) return;

    final result = didDraw ? 'draw' : (winnerId == userId ? 'win' : 'loss');
    final saved = await ScoreService().saveScore(
      Score(
        playerId: userId,
        playerName: 'Online player',
        wins: result == 'win' ? 1 : 0,
        losses: result == 'loss' ? 1 : 0,
        draws: result == 'draw' ? 1 : 0,
        points: result == 'win' ? 3 : (result == 'draw' ? 1 : 0),
      ),
      loggedIn: true,
      opponentType: 'friend',
    );
    _scoreRecorded = saved;
    if (saved) {
      final gameRef = findGame();
      if (gameRef is TicTacToeGame) {
        await gameRef.refreshActiveProfile();
      }
    }
  }

  void handleTap(int row, int col) async {
    if (!_matchReady || gameOver || _moveInFlight || board[row * 3 + col] != '') {
      return;
    }

    final service = SupabaseMatchService();
    if (service.userId == null) return;
    final gameRef = findGame();
    final symbol = gameRef is TicTacToeGame ? gameRef.myPlayerSymbol : null;
    if (symbol == null || currentPlayer != symbol) return;

    _moveInFlight = true;
    try {
      await service.submitMove(matchId: matchId, row: row, col: col);
    } catch (error) {
      debugPrint('Supabase submitMove failed: $error');
    } finally {
      _moveInFlight = false;
    }
    return;

    // Ensure user is signed in and token propagated before attempting move
    // Determine local playerId (signed-in uid preferred, otherwise guest)
    final fb.User? firebaseUser = fb.FirebaseAuth.instance.currentUser;
    final playerId =
        firebaseUser?.uid ?? await GuestService.getOrCreateGuestId();
    if (currentPlayer != playerId) return; // only allow your turn

    final int cellIndex = row * 3 + col;

    try {
      final callable = functions.httpsCallable('makeMove');
      final result = await callable.call({
        'matchId': matchId,
        'playerId': playerId,
        'cellIndex': cellIndex,
      });

      final data = result.data as Map<String, dynamic>;
      if (data['success'] == true) {
        final updatedBoard = List<String>.from(data['board']);
        board = updatedBoard;
        currentPlayer = data['currentTurn'] ?? currentPlayer;

        // Update cell visuals
        for (int i = 0; i < 9; i++) {
          final r = i ~/ 3;
          final c = i % 3;
          final cellComponent = children
              .whereType<TicTacToeCellInvite>()
              .firstWhere((cell) => cell.row == r && cell.col == c);
          if (board[i] != '') cellComponent.mark(board[i]);
        }
      }
    } catch (e) {
      debugPrint('Error calling makeMove Cloud Function: $e');
    }
  }

  void leaveMatch() async {
    matchSubscription?.cancel();
    supabaseMatchSubscription?.cancel();

    // Leave tournament queue if necessary
    try {
      final svc = CompetitionService();
      final user = await svc.waitForSignIn();
      if (user != null) {
        final matchDoc = await firestore
            .collection('matches')
            .doc(matchId)
            .get();
        final isTournament = matchDoc.data()?['tournament'] == true;
        final tournamentId = matchDoc.data()?['tournamentId'] as String?;
        if (isTournament && tournamentId != null) {
          final callable = functions.httpsCallable('leaveTournamentQueue');
          await callable.call({
            'playerId': user.uid,
            'tournamentId': tournamentId,
          });
        }
      }
    } catch (e) {
      debugPrint('Error leaving tournament queue: $e');
    }

    final flameGame = findGame();
    if (flameGame != null) {
      for (final component in List<Component>.from(flameGame.children)) {
        component.removeFromParent();
      }
    }
    final router = (flameGame as dynamic).router;
    router?.pushNamed('menu');
  }

  // Robustly add the end-match overlay with retries so it is not lost
  // during route transitions. Attaches to the provided flameGame root.
  Future<void> _addEndMatchOverlaySafely(
    dynamic flameGame, {
    required bool didWin,
    required bool didDraw,
    String? overrideMessage,
    String? scoreline,
    String? scoreXText,
    String? scoreOText,
    Color? scoreXColor,
    Color? scoreOColor,
  }) async {
    int attempts = 0;
    int delayMs = 80;
    RectangleComponent? dim;
    EndMatchOverlay? overlay;

    while (attempts < 5) {
      try {
        // If overlay present already, nothing to do
        if (flameGame.children.whereType<EndMatchOverlay>().isNotEmpty) return;

        // Create dim if needed
        dim ??= RectangleComponent(
          size: flameGame.size ?? BoardLayout.defaultScreenSize,
          paint: Paint()..color = Colors.black.withValues(alpha: 0.6),
          priority: 1000000000000,
        );

        if (!flameGame.children.contains(dim)) flameGame.add(dim);

        overlay ??= EndMatchOverlay(
          theme: ThemeStore.current,
          didWin: didWin,
          didDraw: didDraw,
          overrideMessage: overrideMessage,
          scoreline: scoreline,
          scoreXText: scoreXText,
          scoreOText: scoreOText,
          scoreXColor: scoreXColor,
          scoreOColor: scoreOColor,
          onNext: () async {
            // Toggle starting symbol preference so rematches alternate
            try {
              final prefs = await SharedPreferences.getInstance();
              final current = prefs.getBool('human_is_x') ?? true;
              await prefs.setBool('human_is_x', !current);
            } catch (_) {}
          },
          onHome: () async {
            // Decide whether to prompt sign-in on Home based on sign-in status and creator/joiner rules.
            final authUser = fb.FirebaseAuth.instance.currentUser;
            if (authUser != null) {
              try {
                dim?.removeFromParent();
              } catch (_) {}
              final router = (flameGame as dynamic).router;
              router?.pushNamed('menu');
              return;
            }

            // Guest user: check which side we are on
            String? mySym;
            try {
              mySym = (flameGame as dynamic).myPlayerSymbol as String?;
            } catch (_) {
              mySym = null;
            }

            // If we are the joiner (typically 'O'), just route home without prompting
            if (mySym != null && mySym == 'O') {
              try {
                dim?.removeFromParent();
              } catch (_) {}
              final router = (flameGame as dynamic).router;
              router?.pushNamed('menu');
              return;
            }

            // Use online match counter to decide prompt frequency (1,11,21...).
            try {
              final prefs = await SharedPreferences.getInstance();
              final cnt = prefs.getInt('online_matches_completed') ?? 0;
              if (cnt % 10 == 1) {
                final gate = AuthGateComponent(
                  onSignedIn: () async {
                    try {
                      dim?.removeFromParent();
                    } catch (_) {}
                  },
                );
                gate.priority = 1006000000000;
                flameGame.add(gate);
                return;
              }
            } catch (e) {
              debugPrint('Sign-in prompt decision failed: $e');
            }

            // Default: just route home
            try {
              dim?.removeFromParent();
            } catch (_) {}
            final router = (flameGame as dynamic).router;
            router?.pushNamed('menu');
          },
          // We'll control sign-in prompting explicitly in onHome, so don't
          // let the overlay auto-show a gate itself.
          showSignInPrompt: false,
          singleHomeButton: true,
        );
        overlay.priority = 1000000000001;
        if (!flameGame.children.contains(overlay)) flameGame.add(overlay);

        // Increment online match counter to control sign-in prompt frequency.
        Future.microtask(() async {
          try {
            final prefs = await SharedPreferences.getInstance();
            int cnt = prefs.getInt('online_matches_completed') ?? 0;
            cnt++;
            await prefs.setInt('online_matches_completed', cnt);
          } catch (e) {
            debugPrint('Failed to update online match counter: $e');
          }
        });

        // Refresh leaderboard (best-effort) so UI can update after server-side scoring
        try {
          final funcs = FirebaseFunctions.instanceFor(region: 'us-central1');
          funcs
              .httpsCallable('getLeaderboard')
              .call({'limit': 10})
              .then((_) {})
              .catchError((_) {});
        } catch (_) {}

        // Verify overlay remains attached briefly and re-add if missing.
        try {
          // Run a short async verification loop to ensure the overlay stays
          // attached; re-add up to ~2.4s (8 checks at 300ms intervals).
          Future.microtask(() async {
            for (int checks = 0; checks < 8; checks++) {
              try {
                await Future.delayed(const Duration(milliseconds: 300));
                final present = flameGame.children
                    .whereType<EndMatchOverlay>()
                    .isNotEmpty;
                if (!present) {
                  try {
                    if (dim != null && !flameGame.children.contains(dim)) {
                      flameGame.add(dim);
                    }
                    if (overlay != null &&
                        !flameGame.children.contains(overlay)) {
                      flameGame.add(overlay);
                    }
                  } catch (_) {}
                }
              } catch (_) {
                break;
              }
            }
          });
        } catch (_) {}

        return;
      } catch (_) {
        // ignore and retry
      }

      await Future.delayed(Duration(milliseconds: delayMs));
      attempts++;
      delayMs *= 2;
    }

    // Final best-effort attempt
    try {
      if (flameGame.children.whereType<EndMatchOverlay>().isNotEmpty) return;
      final finalDim = RectangleComponent(
        size: flameGame.size ?? BoardLayout.defaultScreenSize,
        paint: Paint()..color = Colors.black.withValues(alpha: 0.6),
        priority: 1000000000000,
      );
      flameGame.add(finalDim);
      final finalOverlay = EndMatchOverlay(
        theme: ThemeStore.current,
        didWin: didWin,
        didDraw: didDraw,
        overrideMessage: overrideMessage,
        scoreline: scoreline,
        scoreXText: scoreXText,
        scoreOText: scoreOText,
        scoreXColor: scoreXColor,
        scoreOColor: scoreOColor,
        onNext: () {},
        onHome: () {
          final authUser = fb.FirebaseAuth.instance.currentUser;
          if (authUser == null) {
            final gate = AuthGateComponent(
              onSignedIn: () async {
                try {
                  finalDim.removeFromParent();
                } catch (_) {}
              },
            );
            gate.priority = 1006000000000;
            flameGame.add(gate);
          } else {
            try {
              finalDim.removeFromParent();
            } catch (_) {}
            final router = (flameGame as dynamic).router;
            router?.pushNamed('menu');
          }
        },
        showSignInPrompt: true,
        singleHomeButton: true,
      );
      finalOverlay.priority = 1000000000001;
      flameGame.add(finalOverlay);
    } catch (_) {}
  }

  // Smoke-test helper: attempt to add and then remove an end-match overlay.
  // Returns true if the overlay could be added.
  Future<bool> smokeTestEndMatchOverlay() async {
    final flameGame = findGame();
    if (flameGame == null) return false;
    try {
      await _addEndMatchOverlaySafely(flameGame, didWin: false, didDraw: false);
      // allow a short moment for components to attach
      await Future.delayed(const Duration(milliseconds: 160));
      final present = flameGame.children
          .whereType<EndMatchOverlay>()
          .isNotEmpty;
      // cleanup
      try {
        for (final c in List<Component>.from(
          flameGame.children.whereType<EndMatchOverlay>(),
        )) {
          try {
            c.removeFromParent();
          } catch (_) {}
        }
        for (final r in List<Component>.from(
          flameGame.children.whereType<RectangleComponent>(),
        )) {
          try {
            // remove dims with the same opacity heuristic
            if ((r as RectangleComponent).paint.color.a == 0.6) {
              r.removeFromParent();
            }
          } catch (_) {}
        }
      } catch (_) {}
      return present;
    } catch (_) {
      return false;
    }
  }

  void _startConfetti() {
    if (confettiRunning) return;
    confettiRunning = true;

    final size = findGame()?.size ?? Vector2(layout.screenSize.x, layout.screenSize.y);

    void spawnConfettiPiece() {
      if (!confettiRunning) return;
      final double confettiSize = 4 + random.nextDouble() * 6;
      final paint = Paint()
        ..color = Color.fromARGB(
          255,
          random.nextInt(256),
          random.nextInt(256),
          random.nextInt(256),
        );
      final confetti = RectangleComponent(
        size: Vector2(confettiSize, confettiSize * 1.5),
        paint: paint,
        position: Vector2(random.nextDouble() * size.x, -10),
        anchor: Anchor.center,
      );

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
    Future.delayed(
      const Duration(milliseconds: 2500),
      () => confettiRunning = false,
    );
  }
}

class _WinningLine extends PositionComponent {
  final Vector2 start;
  final Vector2 end;
  final Color color;

  _WinningLine({required this.start, required this.end, required this.color})
    : super(priority: 5);

  @override
  void render(Canvas canvas) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(start.toOffset(), end.toOffset(), paint);
  }
}

class _MatchLoadingModal extends PositionComponent {
  final Vector2 screenSize;
  final GameTheme theme;
  final String? inviteCode;

  _MatchLoadingModal({required Vector2 size, required this.theme, this.inviteCode})
    : screenSize = size,
      super(size: size, position: Vector2.zero(), priority: 100);

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    add(
      RectangleComponent(
        size: screenSize,
        paint: Paint()..color = const Color.fromARGB(165, 0, 0, 0),
      ),
    );

    final panelSize = Vector2(
      screenSize.x * 0.78,
      (screenSize.y * 0.32).clamp(190.0, 240.0),
    );
    final panel = OrnateOverlayPanel(size: panelSize, theme: theme)
      ..position = screenSize / 2
      ..anchor = Anchor.center;
    add(panel);
    add(
      TextComponent(
        text: 'WAITING FOR OPPONENT',
        position: screenSize / 2 - Vector2(0, 34),
        anchor: Anchor.center,
        textRenderer: TextPaint(
          style: TextStyle(
            color: theme.contrastColor,
            fontSize: 17,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
    add(
      TextComponent(
        text: inviteCode == null || inviteCode!.isEmpty
            ? 'Preparing the match...'
            : 'Invite code: $inviteCode',
        position: screenSize / 2 + Vector2(0, 8),
        anchor: Anchor.center,
        textRenderer: TextPaint(
          style: TextStyle(color: theme.contrastColor, fontSize: 14),
        ),
      ),
    );
    add(
      _LoadingDots(
        position: screenSize / 2 + Vector2(0, 48),
        color: theme.gridColor,
      ),
    );
  }
}

class _LoadingDots extends PositionComponent {
  final Color color;
  double _elapsed = 0;

  _LoadingDots({required Vector2 position, required this.color})
    : super(position: position, size: Vector2(64, 16), anchor: Anchor.center);

  @override
  void update(double dt) {
    _elapsed += dt;
    super.update(dt);
  }

  @override
  void render(Canvas canvas) {
    for (var index = 0; index < 3; index++) {
      final pulse = ((sin(_elapsed * 4 - index * 0.7) + 1) / 2);
      final paint = Paint()..color = color.withValues(alpha: 0.35 + pulse * 0.65);
      canvas.drawCircle(Offset(20 + index * 12, 8), 4, paint);
    }
  }
}

class _InviteBoardGrid extends PositionComponent {
  final BoardLayout layout;
  final GameTheme theme;

  _InviteBoardGrid({required this.layout, required this.theme})
    : super(
        position: Vector2(layout.boardX, layout.boardY),
        size: Vector2(layout.cellWidth * 3, layout.cellHeight * 3),
        priority: 0,
      );

  @override
  void render(Canvas canvas) {
    final fill = Paint()..color = theme.boardBackground.withValues(alpha: 0.72);
    canvas.drawRect(size.toRect(), fill);

    final line = Paint()
      ..color = theme.gridColor
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;
    for (var index = 0; index <= 3; index++) {
      final x = index * layout.cellWidth;
      final y = index * layout.cellHeight;
      canvas.drawLine(Offset(x, 0), Offset(x, size.y), line);
      canvas.drawLine(Offset(0, y), Offset(size.x, y), line);
    }
    super.render(canvas);
  }
}

// CELL COMPONENT
class TicTacToeCellInvite extends PositionComponent with TapCallbacks {
  final int row;
  final int col;
  SpriteComponent? markSprite;
  final TicTacToeInviteScreen parentBoard;

  TicTacToeCellInvite({
    required this.row,
    required this.col,
    required Vector2 position,
    required Vector2 size,
    required this.parentBoard,
  }) : super(position: position, size: size);

  @override
  void onTapDown(TapDownEvent event) {
    if (SettingsScreen.buttonSoundOn) FlameAudio.play('tap.wav');
    parentBoard.handleTap(row, col);
  }

  void mark(String symbol) async {
    // symbol may be 'X'/'O' or a player UID; map UIDs to X/O using parentBoard stored ids
    String sym = symbol;
    if (symbol != 'X' && symbol != 'O') {
      if (symbol == parentBoard.playerXUID) {
        sym = 'X';
      } else if (symbol == parentBoard.playerOUID)
        // ignore: curly_braces_in_flow_control_structures
        sym = 'O';
      else {
        // unknown symbol, ignore
        return;
      }
    }

    markSprite?.removeFromParent();
    final markSize = Vector2.all(min(size.x, size.y) * 0.75);
    final themedSprite = await ThemeStore.current.symbolSprite(
      sym,
      markSize.x,
    );
    markSprite = SpriteComponent()
      ..sprite = themedSprite
      ..size = markSize
      ..position = size / 2
      ..anchor = Anchor.center;
    add(markSprite!);
  }
}

// BUTTON COMPONENT
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
    sprite = await Sprite.load(imagePath);
  }

  @override
  void onTapDown(TapDownEvent event) {
    if (SettingsScreen.buttonSoundOn) FlameAudio.play('button.wav');
    _bounceEffect();
    Future.delayed(const Duration(milliseconds: 180), onPressed);
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

// UTILITY: Current Week ID
String getCurrentWeekId() {
  final now = DateTime.now();
  final year = now.year;
  final oneJan = DateTime(year, 1, 1);
  final days = now.difference(oneJan).inDays + 1;
  final week = ((days + oneJan.weekday) / 7).ceil();
  return '$year-W$week';
}
