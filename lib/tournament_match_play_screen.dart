import 'package:flame/components.dart';
import 'package:flutter/material.dart' hide Route;
import 'package:tictactoe_game/tictactoe.dart';
import 'package:tictactoe_game/models/tournament.dart';
import 'package:tictactoe_game/service/tournament_service.dart';
import 'package:tictactoe_game/service/bracket_service.dart';
import 'package:tictactoe_game/service/supabase_match_service.dart';
import 'package:tictactoe_game/game_themes/theme_store.dart';
import 'package:tictactoe_game/components/button.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class TournamentMatchPlayScreen extends Component with HasGameReference<TicTacToeGame> {
  late TournamentService tournamentService;
  late String tournamentId;
  late String userUid;

  Tournament? tournament;
  Map<String, dynamic>? currentMatch;
  String? opponent;
  bool isLoading = true;
  String? errorMessage;
  bool _opponentOnline = false;
  bool _presenceConnected = false;
  bool _walkoverAvailable = false;
  dynamic _presenceChannel;
  TextComponent? _presenceStatus;
  TextComponent? _loadingText;

  TournamentMatchPlayScreen() {
    debugPrint('[TOURNAMENT PLAY SCREEN] Constructor called!');
  }

  @override
  void render(Canvas canvas) {
    debugPrint('[TOURNAMENT PLAY SCREEN] render() called - component IS mounted!');
    super.render(canvas);
  }

  @override
  void onMount() {
    debugPrint('[TOURNAMENT PLAY SCREEN] onMount() called!');
    super.onMount();
  }

  @override
  Future<void> onLoad() async {
    try {
      debugPrint('[TOURNAMENT PLAY SCREEN] onLoad() starting!');
      await super.onLoad();
      debugPrint('[TOURNAMENT PLAY SCREEN] super.onLoad() completed!');
      
      final gameRef = findGame()!;
      debugPrint('[TOURNAMENT PLAY SCREEN] Got gameRef: $gameRef');
      
      final canvasSize = gameRef.size;
      debugPrint('[TOURNAMENT PLAY SCREEN] Got canvasSize: $canvasSize');
      
      tournamentService = TournamentService();
      debugPrint('[TOURNAMENT PLAY SCREEN] Created tournamentService');
      
      tournamentId = (gameRef as dynamic).activeTournamentId ?? '';
      debugPrint('[TOURNAMENT PLAY SCREEN] Got tournamentId: $tournamentId');
      
      userUid = Supabase.instance.client.auth.currentUser?.id ?? '';
      debugPrint('[TOURNAMENT PLAY SCREEN] Got userUid: $userUid');

      if (tournamentId.isEmpty) {
        throw Exception('activeTournamentId is empty! Cannot proceed');
      }

      add(
        RectangleComponent(
          size: canvasSize,
          paint: Paint()..color = ThemeStore.current.boardBackground,
          priority: -1,
        ),
      );

      _renderLoading(canvasSize);
      debugPrint('[TOURNAMENT PLAY SCREEN] Rendered loading screen');

      await _loadTournamentAndMatch();
      debugPrint('[TOURNAMENT PLAY SCREEN] onLoad() completed!');
      
      // Remove the loading overlay once the screen is ready
      _removeMatchLoadingFallback();
    } catch (e, stackTrace) {
      debugPrint('[TOURNAMENT PLAY SCREEN] FATAL ERROR in onLoad: $e');
      debugPrintStack(stackTrace: stackTrace);
      
      final gameRef = findGame();
      if (gameRef != null) {
        add(
          TextComponent(
            text: 'ERROR: $e',
            position: Vector2(gameRef.size.x / 2, gameRef.size.y / 2),
            anchor: Anchor.center,
            textRenderer: TextPaint(
              style: const TextStyle(
                color: Color(0xFFFF6B6B),
                fontSize: 14,
              ),
            ),
          ),
        );
      }
      rethrow;
    }
  }

  void _removeMatchLoadingFallback() {
    Future<void>.delayed(const Duration(milliseconds: 120), () {
      try {
        final game = findGame();
        if (game is TicTacToeGame) {
          debugPrint('[TOURNAMENT PLAY SCREEN] Removing match_loading_fallback overlay');
          game.overlays.remove('match_loading_fallback');
        }
      } catch (e) {
        debugPrint('[TOURNAMENT PLAY SCREEN] Could not remove overlay: $e');
      }
    });
  }

  Future<void> _loadTournamentAndMatch() async {
    try {
      debugPrint('[TOURNAMENT PLAY SCREEN] Loading tournament and match...');
      tournament = await tournamentService.getTournament(tournamentId);
      debugPrint('[TOURNAMENT PLAY SCREEN] Tournament loaded: $tournament');
      
      if (tournament == null) {
        errorMessage = 'Tournament not found';
        isLoading = false;
        _renderSafely();
        return;
      }

      currentMatch = BracketService.getNextMatchForParticipant(
        tournament!.bracket,
        userUid,
      );

      debugPrint('[TOURNAMENT PLAY SCREEN] Current match: $currentMatch');

      if (currentMatch == null) {
        errorMessage = 'No pending matches for you';
        isLoading = false;
        _renderSafely();
        return;
      }

      final opponentValue = currentMatch!['player1'] == userUid
          ? currentMatch!['player2']
          : currentMatch!['player1'];

      opponent = opponentValue?.toString();
      debugPrint('[TOURNAMENT PLAY SCREEN] Opponent loaded: $opponent');

      isLoading = false;
      _renderSafely();
      _connectToMatchPresence();

    } catch (e) {
      debugPrint('[TOURNAMENT PLAY SCREEN] ERROR: $e');
      errorMessage = 'Error loading tournament: $e';
      isLoading = false;
      _renderSafely();
    }
  }

  void _renderLoading(Vector2 canvasSize) {
    _loadingText = TextComponent(
      text: 'LOADING TOURNAMENT MATCH...',
      position: Vector2(canvasSize.x / 2, canvasSize.y / 2),
      anchor: Anchor.center,
      textRenderer: TextPaint(
        style: TextStyle(
          color: ThemeStore.current.contrastColor,
          fontSize: 16,
        ),
      ),
    );
    add(_loadingText!);
  }

  void _renderSafely() {
    _loadingText?.removeFromParent();
    _loadingText = null;
    try {
      _renderContent();
    } catch (e, stackTrace) {
      debugPrint('Could not render tournament match screen: $e');
      debugPrintStack(stackTrace: stackTrace);
      final gameRef = findGame();
      if (gameRef == null) return;
      add(
        TextComponent(
          text: 'COULD NOT OPEN MATCH',
          position: Vector2(gameRef.size.x / 2, gameRef.size.y / 2),
          anchor: Anchor.center,
          textRenderer: TextPaint(
            style: TextStyle(
              color: const Color(0xFFFF6B6B),
              fontSize: 16,
            ),
          ),
        ),
      );
    }
  }

  void _renderContent() {
    final gameRef = findGame()!;
    final canvasSize = gameRef.size;

    if (errorMessage != null) {
      add(
        TextComponent(
          text: errorMessage!,
          position: Vector2(canvasSize.x / 2, canvasSize.y / 2),
          anchor: Anchor.center,
          textRenderer: TextPaint(
            style: TextStyle(
              color: const Color(0xFFFF6B6B),
              fontSize: 16,
            ),
          ),
        ),
      );

      add(
        ButtonComponent(
          label: 'BACK',
          position: Vector2(canvasSize.x / 2, canvasSize.y / 2 + 100),
          size: Vector2(100, 40),
          theme: ThemeStore.current,
          onPressed: () {
            (gameRef as TicTacToeGame).router.pushReplacementNamed('tournament_detail');
          },
        ),
      );

      return;
    }

    if (isLoading || currentMatch == null) {
      add(
        TextComponent(
          text: 'Loading...',
          position: Vector2(canvasSize.x / 2, canvasSize.y / 2),
          anchor: Anchor.center,
          textRenderer: TextPaint(
            style: TextStyle(
              color: ThemeStore.current.contrastColor,
              fontSize: 16,
            ),
          ),
        ),
      );

      return;
    }

    add(
      TextComponent(
        text: (tournament?.name ?? 'Tournament').toUpperCase(),
        position: Vector2(canvasSize.x / 2, 30),
        anchor: Anchor.center,
        textRenderer: TextPaint(
          style: TextStyle(
            color: ThemeStore.current.contrastColor,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );

    final position =
        (currentMatch!['position'] as num?)?.toInt() ?? 0;
    add(
      TextComponent(
        text: 'ROUND ${currentMatch!['round']} • MATCH ${position + 1}',
        position: Vector2(canvasSize.x / 2, 60),
        anchor: Anchor.center,
        textRenderer: TextPaint(
          style: TextStyle(
            color: ThemeStore.current.contrastColor.withValues(alpha: 0.7),
            fontSize: 12,
          ),
        ),
      ),
    );

    final opponentLabel = opponent == null
        ? 'OPPONENT'
        : opponent!.length > 8
            ? opponent!.substring(0, 8).toUpperCase()
            : opponent!.toUpperCase();

    add(
      TextComponent(
        text: 'VS $opponentLabel',
        position: Vector2(canvasSize.x / 2, 90),
        anchor: Anchor.center,
        textRenderer: TextPaint(
          style: TextStyle(
            color: ThemeStore.current.contrastColor,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );

    _presenceStatus = TextComponent(
      text: 'CHECKING OPPONENT STATUS...',
      position: Vector2(canvasSize.x / 2, 125),
      anchor: Anchor.center,
      textRenderer: TextPaint(
        style: TextStyle(
          color: ThemeStore.current.contrastColor.withValues(alpha: 0.8),
          fontSize: 13,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
    add(_presenceStatus!);

    // Either player can start — presence is advisory only.
    debugPrint('[TOURNAMENT PLAY SCREEN] Adding PLAY MATCH button. Opponent=$opponent, CurrentMatch=$currentMatch');
    add(
      ButtonComponent(
        label: 'PLAY MATCH',
        position: Vector2(canvasSize.x / 2, canvasSize.y / 2 + 20),
        size: Vector2(150, 50),
        theme: ThemeStore.current,
        onPressed: () async {
          debugPrint('[TOURNAMENT PLAY] PLAY MATCH button pressed!');
          if (opponent == null || opponent!.isEmpty) {
            debugPrint('[TOURNAMENT PLAY] Opponent is null or empty');
            _presenceStatus?.text = 'NO OPPONENT ASSIGNED YET';
            return;
          }

          try {
            _presenceStatus?.text = 'STARTING ONLINE MATCH...';
            debugPrint('[TOURNAMENT PLAY] User $userUid starting match against $opponent');
            final boardSize = _gridSizeValue(tournament!.gridSize);
            final winLength = boardSize.clamp(3, boardSize);

            debugPrint('[TOURNAMENT PLAY] Calling startOrJoinTournamentMatch...');
            final match = await SupabaseMatchService().startOrJoinTournamentMatch(
              tournamentId: tournamentId,
              tournamentMatchId: currentMatch!['id'].toString(),
              boardSize: boardSize,
              winLength: winLength,
              opponentId: opponent!,
            );

            debugPrint('[TOURNAMENT PLAY] Got match: ${match['id']}');
            final onlineMatchId = match['id']?.toString();
            if (onlineMatchId == null || onlineMatchId.isEmpty) {
              throw StateError('Online match was not created');
            }

            try {
              await _presenceChannel?.send(
                type: 'broadcast',
                event: 'match_ready',
                payload: {'matchId': onlineMatchId},
              );
            } catch (_) {}

            final mySymbol = (match['player_x']?.toString() == userUid)
                ? 'X'
                : 'O';

            debugPrint('[TOURNAMENT PLAY] Opening match $onlineMatchId as $mySymbol');
            _openOnlineMatch(onlineMatchId, mySymbol);

          } catch (e) {
            debugPrint('Could not start tournament match: $e');
            _presenceStatus?.text = 'COULD NOT START MATCH - TRY AGAIN';
          }
        },
      ),
    );

    add(
      ButtonComponent(
        label: 'BACK',
        position: Vector2(canvasSize.x / 2, canvasSize.y - 55),
        size: Vector2(150, 40),
        theme: ThemeStore.current,
        onPressed: () {
          (gameRef as TicTacToeGame).router.pushReplacementNamed('tournament_detail');
        },
      ),
    );
  }

  int _gridSizeValue(GridSize size) {
    switch (size) {
      case GridSize.small:
        return 3;
      case GridSize.medium:
        return 4;
      case GridSize.large:
        return 5;
    }
  }

  void _openOnlineMatch(String onlineMatchId, String symbol) {
    final gameRef = findGame() as TicTacToeGame;
    gameRef.pendingMatchId = onlineMatchId;
    gameRef.pendingMatchIsTournament = true;
    gameRef.myPlayerSymbol = symbol;
    gameRef.tournamentMatchData = {
      'tournamentId': tournamentId,
      'tournamentMatchId': currentMatch!['id'],
      'onlineMatchId': onlineMatchId,
      'opponent': opponent,
      'player1': currentMatch!['player1'],
      'player2': currentMatch!['player2'],
      'gridSize': tournament!.gridSize,
    };
    gameRef.router.pushReplacementNamed('invite');
  }

  Future<void> _connectToMatchPresence() async {
    if (opponent == null || opponent!.isEmpty || userUid.isEmpty) return;

    try {
      final channel = Supabase.instance.client.channel(
        'tournament_match_${tournamentId}_${currentMatch!['id']}',
      ) as dynamic;

      _presenceChannel = channel;

      channel.onPresenceSync((dynamic _) {
        _presenceConnected = true;
        _updatePresenceStatus();
        _refreshOpponentPresence(channel);
      });

      channel.onPresenceJoin((dynamic _) {
        _refreshOpponentPresence(channel);
      });

      channel.onPresenceLeave((dynamic _) {
        _refreshOpponentPresence(channel);
      });

      channel.onBroadcast(
        event: 'match_ready',
        callback: (dynamic payload) {
          final data = payload is Map ? payload['payload'] : null;
          final matchId = data is Map ? data['matchId']?.toString() : null;

          if (matchId == null || matchId.isEmpty) return;

          _openOnlineMatch(
            matchId,
            userUid == currentMatch!['player1'] ? 'X' : 'O',
          );
        },
      );

      await channel.subscribe((status, [error]) async {
        if (status.toString().contains('SUBSCRIBED') ||
            status.toString().contains('subscribed')) {
          try {
            await channel.track({
              'user_id': userUid,
              'match_id': currentMatch!['id'],
            });
          } catch (e) {
            debugPrint('Presence track failed: $e');
          }
        }
      });

      _presenceConnected = true;
      _updatePresenceStatus();
      _pollExistingOnlineMatch();

    } catch (e) {
      debugPrint('Tournament presence unavailable: $e');
      _presenceStatus?.text = 'PRESENCE UNAVAILABLE - YOU CAN STILL PLAY';
      _pollExistingOnlineMatch();
    }
  }

  Future<void> _pollExistingOnlineMatch() async {
    if (currentMatch == null || opponent == null) return;

    try {
      final code = SupabaseMatchService.tournamentMatchInviteCode(
        tournamentId: tournamentId,
        tournamentMatchId: currentMatch!['id'].toString(),
      );

      final existing = await SupabaseMatchService().getMatchByInviteCode(code);
      if (existing != null && existing['id'] != null) {
        final status = (existing['status'] ?? '').toString();
        if (status == 'active' || status == 'waiting') {
          final onlineMatchId = existing['id'].toString();
          final mySymbol =
              existing['player_x']?.toString() == userUid ? 'X' : 'O';
          _presenceStatus?.text = 'MATCH FOUND - JOINING...';
          _openOnlineMatch(onlineMatchId, mySymbol);
        }
      }
    } catch (e) {
      debugPrint('Poll existing tournament match failed: $e');
    }
  }

  void _refreshOpponentPresence(dynamic channel) {
    try {
      final state = channel.presenceState();
      _opponentOnline = _containsValue(state, opponent!);
      _updatePresenceStatus();
    } catch (e) {
      debugPrint('Could not read tournament presence: $e');
    }
  }

  bool _containsValue(dynamic value, String expected) {
    if (value is String) return value == expected;
    if (value is Map) {
      return value.entries.any(
        (entry) => _containsValue(entry.key, expected) ||
            _containsValue(entry.value, expected),
      );
    }
    if (value is Iterable) {
      return value.any((item) => _containsValue(item, expected));
    }
    return false;
  }

  void _updatePresenceStatus() {
    if (_opponentOnline) {
      _presenceStatus?.text = 'OPPONENT ONLINE - READY TO PLAY';
    } else if (_presenceConnected) {
      _presenceStatus?.text = _walkoverAvailable
          ? 'OPPONENT OFFLINE - WALKOVER AVAILABLE'
          : 'WAITING FOR OPPONENT (YOU CAN STILL PLAY)';
    }
  }

  @override
  void update(double dt) {
    super.update(dt);

    if (isLoading || currentMatch == null || _opponentOnline) return;

    final deadline = DateTime.tryParse(
      currentMatch!['deadline']?.toString() ?? '',
    );

    if (deadline != null &&
        DateTime.now().isAfter(deadline) &&
        !_walkoverAvailable) {
      _walkoverAvailable = true;
      _updatePresenceStatus();
      _addWalkoverButton();
    }
  }

  void _addWalkoverButton() {
    final gameRef = findGame()!;
    add(
      ButtonComponent(
        label: 'CLAIM WALKOVER',
        position: Vector2(gameRef.size.x / 2, gameRef.size.y / 2 + 90),
        size: Vector2(190, 42),
        theme: ThemeStore.current,
        onPressed: _claimWalkover,
      ),
    );
  }

  Future<void> _claimWalkover() async {
    if (currentMatch == null || opponent == null || _opponentOnline) return;

    final success = await tournamentService.forfeitMatch(
      tournamentId: tournamentId,
      matchId: currentMatch!['id'] as String,
    );

    _presenceStatus?.text = success
        ? 'WALKOVER CONFIRMED - YOU ADVANCE'
        : 'WALKOVER FAILED - REFRESH AND TRY AGAIN';

    if (success) {
      await Future<void>.delayed(const Duration(milliseconds: 800));
      (findGame() as TicTacToeGame).router.pushReplacementNamed('tournament_detail');
    }
  }

  @override
  void onRemove() {
    _removeMatchLoadingFallback();
    final channel = _presenceChannel;
    if (channel != null) {
      try {
        Supabase.instance.client.removeChannel(channel);
      } catch (_) {}
    }
    super.onRemove();
  }
}
