import 'dart:async';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/effects.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tictactoe_game/end_match_overlay.dart';
import 'components/auth_gate_component.dart';
import 'package:flame_audio/flame_audio.dart';
import 'package:tictactoe_game/settings_screen.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'service/competition_service.dart';
import 'service/score_service.dart';
import 'models/score.dart';
import 'tictactoe.dart';
import 'service/guest_service.dart';

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

  final double cellWidth = 390 / 3;
  final double cellHeight = 321 / 3;
  final double boardX = 4;
  final double boardY = 318;

  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  final FirebaseFunctions functions = FirebaseFunctions.instanceFor(
    region: 'us-central1',
  );
  StreamSubscription<DocumentSnapshot>? matchSubscription;
  bool _aiMoveScheduled = false;

  bool confettiRunning = false;
  final Random random = Random();
  final List<Component> confettiPieces = [];
  bool _addedReturnButton = false;

  TicTacToeInviteScreen({required this.matchId});

  @override
  Future<void> onLoad() async {
    board = List.filled(9, '');
    currentPlayer = 'X';

    final canvasSize = findGame()?.size ?? Vector2(360, 640);

    // Background
    final background = SpriteComponent()
      ..sprite =
          await (findGame()?.loadSprite('playscreen.png') ??
              Sprite.load('playscreen.png'))
      ..size = canvasSize
      ..position = Vector2.zero();
    add(background);

    // Message text
    messageText = TextComponent(
      text: "Waiting for opponent...",
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

    // Player name placeholders (left and right)
    playerXNameText = TextComponent(
      text: '',
      position: Vector2(20, 40),
      anchor: Anchor.topLeft,
      textRenderer: TextPaint(
        style: const TextStyle(
          fontSize: 16,
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
      ),
    )..priority = 10010;
    add(playerXNameText);

    playerONameText = TextComponent(
      text: '',
      position: Vector2(canvasSize.x - 20, 40),
      anchor: Anchor.topRight,
      textRenderer: TextPaint(
        style: const TextStyle(
          fontSize: 16,
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
        size: Vector2(28, 28),
        // place the small symbol below the name text (shifted left slightly)
        position: Vector2(60, 66),
        anchor: Anchor.topLeft,
      )..priority = 10011;
      add(playerXSymbolSprite!);
    } catch (_) {}

    try {
      smallOSprite =
          await (findGame()?.loadSprite('O.png') ?? Sprite.load('O.png'));
      playerOSymbolSprite = SpriteComponent(
        sprite: smallOSprite,
        size: Vector2(28, 28),
        // place the small symbol below the name text on the right side
        position: Vector2(canvasSize.x - 60, 66),
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
              boardX + col * cellWidth,
              boardY + row * cellHeight,
            ),
            size: Vector2(cellWidth, cellHeight),
            parentBoard: this,
          ),
        );
      }
    }

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
              add(
                _PressdownButton(
                  imagePath: 'return.png',
                  position: Vector2(40, 180),
                  size: Vector2(60, 60),
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
              if (px != null)
                pxName = (px['displayName'] ?? px['name'] ?? '') as String;
              if (po != null)
                poName = (po['displayName'] ?? po['name'] ?? '') as String;
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
              if (pxName.isEmpty)
                pxName = (data['playerXName'] ?? '') as String;
              if (poName.isEmpty)
                poName = (data['playerOName'] ?? '') as String;
              if (pxName.isEmpty)
                pxName = playerXUID.isNotEmpty ? playerXUID : 'Player X';
              if (poName.isEmpty)
                poName = playerOUID.isNotEmpty ? playerOUID : 'Player O';

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
                  if (playerXSymbolSprite != null && smallXSprite != null)
                    playerXSymbolSprite!.sprite = smallXSprite;
                  if (playerOSymbolSprite != null && smallOSprite != null)
                    playerOSymbolSprite!.sprite = smallOSprite;
                } else {
                  playerXNameText.text = poName;
                  playerONameText.text = pxName;
                  if (playerXSymbolSprite != null && smallOSprite != null)
                    playerXSymbolSprite!.sprite = smallOSprite;
                  if (playerOSymbolSprite != null && smallXSprite != null)
                    playerOSymbolSprite!.sprite = smallXSprite;
                }
              } else {
                if (myUID == playerXUID) {
                  playerXNameText.text = pxName;
                  playerONameText.text = poName;
                  if (playerXSymbolSprite != null && smallXSprite != null)
                    playerXSymbolSprite!.sprite = smallXSprite;
                  if (playerOSymbolSprite != null && smallOSprite != null)
                    playerOSymbolSprite!.sprite = smallOSprite;
                } else {
                  playerXNameText.text = poName;
                  playerONameText.text = pxName;
                  if (playerXSymbolSprite != null && smallOSprite != null)
                    playerXSymbolSprite!.sprite = smallOSprite;
                  if (playerOSymbolSprite != null && smallXSprite != null)
                    playerOSymbolSprite!.sprite = smallXSprite;
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
                        if (isLeft) {
                          if (playerXFlagSprite == null) {
                            playerXFlagSprite = SpriteComponent(
                              sprite: sp,
                              size: Vector2(28, 18),
                              position: Vector2(140, 44),
                              anchor: Anchor.centerLeft,
                            )..priority = 10012;
                            add(playerXFlagSprite!);
                          } else {
                            playerXFlagSprite!.sprite = sp;
                          }
                        } else {
                          if (playerOFlagSprite == null) {
                            playerOFlagSprite = SpriteComponent(
                              sprite: sp,
                              size: Vector2(28, 18),
                              position: Vector2(
                                (findGame()?.size.x ?? 360) - 140,
                                44,
                              ),
                              anchor: Anchor.centerRight,
                            )..priority = 10012;
                            add(playerOFlagSprite!);
                          } else {
                            playerOFlagSprite!.sprite = sp;
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
              // Cancel any pending AI scheduling so client won't trigger further moves
              _aiMoveScheduled = false;
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
                      if ((data['playerXUID'] ?? '') != '')
                        players.add(data['playerXUID']);
                      if ((data['playerOUID'] ?? '') != '')
                        players.add(data['playerOUID']);
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

              // If opponent is an AI, schedule server-side AI move after a short delay
              try {
                final opponentId = (data['playerOUID'] ?? '') as String;
                if ((opponentId.startsWith('ai_') ||
                        opponentId.startsWith('bot_')) &&
                    currentPlayer == opponentId &&
                    !_aiMoveScheduled) {
                  _aiMoveScheduled = true;
                  final delayMs = 500 + Random().nextInt(2500); // 0.5s..3s
                  Future.delayed(Duration(milliseconds: delayMs), () async {
                    try {
                      final functions = FirebaseFunctions.instanceFor(
                        region: 'us-central1',
                      );
                      await functions.httpsCallable('requestAiMove').call({
                        'matchId': matchId,
                      });
                    } catch (e) {
                      debugPrint('requestAiMove failed: $e');
                    } finally {
                      _aiMoveScheduled = false;
                    }
                  });
                }
              } catch (_) {}
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

  void handleTap(int row, int col) async {
    if (gameOver || board[row * 3 + col] != '') return;

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
          size: flameGame.size ?? Vector2(360, 640),
          paint: Paint()..color = Colors.black.withOpacity(0.6),
          priority: 1000000000000,
        );

        if (!flameGame.children.contains(dim)) flameGame.add(dim);

        overlay ??= EndMatchOverlay(
          didWin: didWin,
          didDraw: didDraw,
          overrideMessage: overrideMessage,
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
                gate.priority = 10060;
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
                    if (dim != null && !flameGame.children.contains(dim))
                      flameGame.add(dim);
                    if (overlay != null &&
                        !flameGame.children.contains(overlay))
                      flameGame.add(overlay);
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
        size: flameGame.size ?? Vector2(360, 640),
        paint: Paint()..color = Colors.black.withOpacity(0.6),
        priority: 1000000000000,
      );
      flameGame.add(finalDim);
      final finalOverlay = EndMatchOverlay(
        didWin: didWin,
        didDraw: didDraw,
        overrideMessage: overrideMessage,
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
            gate.priority = 10060;
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
            if ((r as RectangleComponent).paint.color.opacity == 0.6)
              r.removeFromParent();
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

    final size = findGame()?.size ?? Vector2(360, 640);

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
      if (symbol == parentBoard.playerXUID)
        sym = 'X';
      else if (symbol == parentBoard.playerOUID)
        sym = 'O';
      else {
        // unknown symbol, ignore
        return;
      }
    }

    markSprite?.removeFromParent();
    markSprite = SpriteComponent()
      ..sprite = await Sprite.load(sym == 'X' ? 'X.png' : 'O.png')
      ..size = Vector2(70, 70)
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
