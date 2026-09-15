import 'dart:async' as async;
import 'dart:math';

import 'package:flame/components.dart';
import 'package:flutter/material.dart' hide Route;
import 'package:tictactoe_game/tictactoe.dart';
import 'package:tictactoe_game/models/tournament.dart';
import 'package:tictactoe_game/service/tournament_service.dart';
import 'package:tictactoe_game/service/bracket_service.dart';
import 'package:tictactoe_game/service/supabase_match_service.dart';
import 'package:tictactoe_game/game_themes/theme_store.dart';
import 'package:tictactoe_game/game_themes/theme.dart';
import 'package:tictactoe_game/components/button.dart';
import 'package:tictactoe_game/components/ornate_overlay_panel.dart';
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
  bool _connectionInProgress = false;
  bool _matchCreationStarted = false;
  async.Timer? _matchLookupTimer;
  bool _presenceConnected = false;
  bool _walkoverAvailable = false;
  dynamic _presenceChannel;
  TextComponent? _presenceStatus;

  @override
  Future<void> onLoad() async {
    final gameRef = findGame()!;
    final canvasSize = gameRef.size;
    tournamentService = TournamentService();
    tournamentId = (gameRef as dynamic).activeTournamentId ?? '';
    userUid = Supabase.instance.client.auth.currentUser?.id ?? '';

    // Background
    add(
      RectangleComponent(
        size: canvasSize,
        paint: Paint()..color = ThemeStore.current.boardBackground,
        priority: -1,
      ),
    );
    _renderLoading(canvasSize);

    // Load tournament and match
    await _loadTournamentAndMatch();
  }

  Future<void> _loadTournamentAndMatch() async {
    try {
      tournament = await tournamentService
          .getTournament(tournamentId)
          .timeout(const Duration(seconds: 15));
      
      if (tournament == null) {
        errorMessage = 'Tournament not found';
        isLoading = false;
        _renderSafely();
        return;
      }

      // Get next match for this player
      currentMatch = BracketService.getNextMatchForParticipant(
        tournament!.bracket,
        userUid,
      );

      if (currentMatch == null) {
        errorMessage = 'No pending matches for you';
        isLoading = false;
        _renderSafely();
        return;
      }

      // Determine opponent
      final opponentValue = currentMatch!['player1'] == userUid
          ? currentMatch!['player2']
          : currentMatch!['player1'];
      opponent = opponentValue?.toString();

      isLoading = false;
      _renderSafely();
      _connectToMatchPresence();
    } catch (e) {
      errorMessage = e is async.TimeoutException
          ? 'CONNECTION TIMED OUT - CHECK YOUR NETWORK AND TRY AGAIN'
          : 'Error loading tournament: $e';
      isLoading = false;
      debugPrint('Error: $e');
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

  /// Hides the instant "match connection" fallback overlay once this screen's
  /// own Flame content is ready to be drawn, so we never leave a stale loading
  /// panel covering the live match lobby. The short delay lets Flame finish
  /// mounting the route so there is no blank frame between overlay and board.
  void _removeRouteFallback() {
    Future<void>.delayed(const Duration(milliseconds: 120), () {
      try {
        final gameRef = findGame();
        if (gameRef is TicTacToeGame) {
          gameRef.overlays.remove('match_loading_fallback');
        }
      } catch (_) {}
    });
  }

  void _renderContent() {
    _removeRouteFallback();
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

    // Tournament name
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

    // Match info
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

    // Opponent display
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

    // Play button
    add(
      ButtonComponent(
        label: 'PLAY MATCH',
        position: Vector2(canvasSize.x / 2, canvasSize.y / 2 + 20),
        size: Vector2(150, 50),
        theme: ThemeStore.current,
        onPressed: () async {
          await _beginConnection();
        },
      ),
    );

    // Back button
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

  Future<void> _beginConnection() async {
    if (_connectionInProgress || currentMatch == null) return;
    _connectionInProgress = true;
    _presenceStatus?.text = 'CONNECTING TO PLAYER...';
    _showConnectionLobby('CONNECTING TO PLAYER...');
    try {
      if (_presenceChannel == null) {
        throw StateError('Match lobby is not connected');
      }
      _setConnectionMessage('BUILDING MATCH BOARD...');
      if (userUid == currentMatch!['player1']) {
        await _createAndOpenMatch();
      } else {
        _setConnectionMessage('READY. WAITING FOR PLAYER 1 TO BUILD THE MATCH...');
        _watchForCreatedMatch();
      }
    } catch (error) {
      debugPrint('Tournament connection lobby failed: $error');
      _showConnectionFailure('Connection failed. Please try again.');
    }
  }

  Future<void> _createAndOpenMatch() async {
    if (_matchCreationStarted) return;
    _matchCreationStarted = true;
    try {
      _setConnectionMessage('CREATING ONLINE MATCH...');
      final created = await SupabaseMatchService().createMatch(
        boardSize: _gridSizeValue(tournament!.gridSize),
        winLength: 3,
        opponentId: opponent,
        inviteCode: currentMatch!['id']?.toString(),
      );
      final onlineMatchId = created['id']?.toString();
      if (onlineMatchId == null || onlineMatchId.isEmpty) {
        throw StateError('Online match was not created');
      }
      final verified = await SupabaseMatchService().getMatch(onlineMatchId);
      if (verified == null) throw StateError('Created match could not be verified');
      await _presenceChannel.send(
        type: 'broadcast',
        event: 'match_ready',
        payload: {'matchId': onlineMatchId},
      );
      _setConnectionMessage('MATCH CONNECTED. OPENING BOARD...');
      await Future<void>.delayed(const Duration(milliseconds: 350));
      _openOnlineMatch(onlineMatchId, 'X');
    } catch (error) {
      _matchCreationStarted = false;
      debugPrint('Could not create tournament match: $error');
      _showConnectionFailure('Connection failed while building the match.');
    }
  }

  void _watchForCreatedMatch() {
    _matchLookupTimer?.cancel();
    _matchLookupTimer = async.Timer.periodic(
      const Duration(seconds: 2),
      (_) async {
        try {
          final match = await SupabaseMatchService().getMatchByInviteCode(
            currentMatch!['id'].toString(),
          );
          final onlineMatchId = match?['id']?.toString();
          if (onlineMatchId == null || onlineMatchId.isEmpty) return;
          _matchLookupTimer?.cancel();
          _matchLookupTimer = null;
          _setConnectionMessage('MATCH CONNECTED. OPENING BOARD...');
          _openOnlineMatch(onlineMatchId, 'O');
        } catch (error) {
          debugPrint('Tournament match lookup failed: $error');
        }
      },
    );
  }

  void _showConnectionLobby(String message) {
    _connectionOverlay?.removeFromParent();
    _connectionOverlay = _ConnectionLobbyOverlay(
      theme: ThemeStore.current,
      message: message,
      onRetry: _retryConnection,
      onCancel: () {
        _connectionInProgress = false;
        _connectionOverlay?.removeFromParent();
      },
    );
    add(_connectionOverlay!);
  }

  void _setConnectionMessage(String message) {
    _connectionOverlay?.setMessage(message);
    _presenceStatus?.text = message;
  }

  void _showConnectionFailure(String message) {
    _connectionInProgress = false;
    _showConnectionLobby(message);
    _connectionOverlay?.showFailure();
    _presenceStatus?.text = message;
  }

  Future<void> _retryConnection() async {
    _connectionOverlay?.removeFromParent();
    _connectionOverlay = null;
    _opponentOnline = false;
    if (!_presenceConnected) {
      // The lobby never connected in the first place - tear down the old
      // channel and try to establish presence again so RETRY can succeed.
      final oldChannel = _presenceChannel;
      if (oldChannel != null) {
        try {
          Supabase.instance.client.removeChannel(oldChannel);
        } catch (_) {}
        _presenceChannel = null;
      }
      _presenceStatus?.text = 'RECONNECTING TO PLAYER...';
      _showConnectionLobby('RECONNECTING TO PLAYER...');
      await _connectToMatchPresence();
      if (!_presenceConnected) {
        _showConnectionFailure('Still unable to connect to the match lobby.');
        return;
      }
    }
    await _beginConnection();
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
      'deadline': currentMatch!['deadline'],
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
        _opponentOnline = true;
        _updatePresenceStatus();
      });
      channel.onPresenceLeave((dynamic _) {
        _refreshOpponentPresence(channel);
      });
      await channel
          .subscribe()
          .timeout(const Duration(seconds: 10));
      await channel
          .track({'user_id': userUid, 'match_id': currentMatch!['id']})
          .timeout(const Duration(seconds: 10));
      _presenceConnected = true;
      _updatePresenceStatus();
    } catch (e) {
      debugPrint('Tournament presence unavailable: $e');
      _presenceConnected = false;
      _presenceStatus?.text = 'PRESENCE UNAVAILABLE - TRY AGAIN';
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
      final deadline = DateTime.tryParse(
        currentMatch?['deadline']?.toString() ?? '',
      );
      if (_walkoverAvailable) {
        _presenceStatus?.text = 'OPPONENT DID NOT JOIN\n[CLAIM WALKOVER]';
      } else if (deadline != null) {
        final remaining = deadline.difference(DateTime.now());
        _presenceStatus?.text =
            'OPPONENT OFFLINE\n'
            'JOIN DEADLINE: ${_formatDeadline(deadline)}\n'
            'WALKOVER AVAILABLE IN: ${_formatRemaining(remaining)}';
      } else {
        _presenceStatus?.text = 'OPPONENT OFFLINE';
      }
    }
  }

  String _formatDeadline(DateTime deadline) {
    final local = deadline.toLocal();
    final weekday = <String>['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][local.weekday - 1];
    final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final minute = local.minute.toString().padLeft(2, '0');
    final suffix = local.hour >= 12 ? 'PM' : 'AM';
    return '$weekday ${local.month}/${local.day}, $hour:$minute $suffix';
  }

  String _formatRemaining(Duration remaining) {
    if (remaining.isNegative || remaining == Duration.zero) return 'NOW';
    final hours = remaining.inHours;
    final minutes = remaining.inMinutes.remainder(60);
    return '${hours}h ${minutes}m';
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
    } else if (!_walkoverAvailable) {
      _updatePresenceStatus();
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
    _removeRouteFallback();
    _matchLookupTimer?.cancel();
    final channel = _presenceChannel;
    if (channel != null) {
      try {
        Supabase.instance.client.removeChannel(channel);
      } catch (_) {}
    }
    super.onRemove();
  }
}

class _ConnectionLobbyOverlay extends PositionComponent {
  final GameTheme theme;
  final VoidCallback onRetry;
  final VoidCallback onCancel;
  String message;
  TextComponent? _messageText;

  _ConnectionLobbyOverlay({
    required this.theme,
    required this.message,
    required this.onRetry,
    required this.onCancel,
  }) : super(priority: 100000, anchor: Anchor.topLeft);

  @override
  Future<void> onLoad() async {
    final game = findGame();
    if (game != null) size = game.size;
    add(InputBlockingDim(
      size: size,
      color: const Color.fromARGB(190, 0, 0, 0),
      priority: -1,
    ));
    final panelSize = Vector2(min(size.x - 36, 340), 230);
    add(OrnateOverlayPanel(size: panelSize, theme: theme)
      ..position = size / 2
      ..anchor = Anchor.center);
    add(TextComponent(
      text: 'MATCH CONNECTION',
      position: size / 2 - Vector2(0, 76),
      anchor: Anchor.center,
      textRenderer: TextPaint(
        style: TextStyle(
          color: theme.contrastColor,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
    ));
    _messageText = TextComponent(
      text: message,
      position: size / 2 - Vector2(0, 28),
      anchor: Anchor.center,
      textRenderer: TextPaint(
        style: TextStyle(color: theme.contrastColor, fontSize: 13),
      ),
    );
    add(_messageText!);
    add(TextComponent(
      text: '...',
      position: size / 2 + Vector2(0, 22),
      anchor: Anchor.center,
      textRenderer: TextPaint(
        style: TextStyle(color: theme.gridColor, fontSize: 18),
      ),
    ));
    add(ButtonComponent(
      label: 'RETRY',
      position: size / 2 + Vector2(-72, 76),
      size: Vector2(110, 38),
      theme: theme,
      onPressed: onRetry,
    ));
    add(ButtonComponent(
      label: 'CANCEL',
      position: size / 2 + Vector2(72, 76),
      size: Vector2(110, 38),
      theme: theme,
      onPressed: onCancel,
    ));
    _updateButtonVisibility();
  }

  void setMessage(String nextMessage) {
    message = nextMessage;
    _messageText?.text = nextMessage;
  }

  void showFailure() {
    setMessage('$message\nTap RETRY to reconnect.');
    _updateButtonVisibility();
  }

  void _updateButtonVisibility() {
    // RETRY remains available throughout, while the animated lobby stays
    // visible so intermediate connection states never expose a blank route.
  }
}
