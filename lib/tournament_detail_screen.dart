import 'dart:async' as async_tools;
import 'dart:math';

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flutter/material.dart' hide Route;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tictactoe_game/components/button.dart';
import 'package:tictactoe_game/confirmation_overlay.dart';
import 'package:tictactoe_game/game_themes/theme_store.dart';
import 'package:tictactoe_game/models/tournament.dart';
import 'package:tictactoe_game/service/bracket_service.dart';
import 'package:tictactoe_game/service/tournament_service.dart';
import 'package:tictactoe_game/tictactoe.dart';

class TournamentDetailScreen extends Component with HasGameReference<TicTacToeGame> {
  late TournamentService tournamentService;
  late String tournamentId;
  Tournament? tournament;
  String? userUid;
  bool isStarting = false;
  int _activeTab = 1;
  final List<Component> _content = [];
  async_tools.Timer? _refreshTimer;

  @override
  Future<void> onLoad() async {
    final game = findGame()!;
    tournamentService = TournamentService();
    tournamentId = (game as TicTacToeGame).activeTournamentId ?? '';
    userUid = Supabase.instance.client.auth.currentUser?.id;
    add(RectangleComponent(
      size: game.size,
      paint: Paint()..color = ThemeStore.current.boardBackground,
      priority: -1,
    ));
    await _loadTournament();
    _startRefreshTimer();
  }

  Future<void> _loadTournament() async {
    debugPrint('[DETAIL LOAD] Loading tournament $tournamentId');
    tournament = await tournamentService.getTournament(tournamentId);
    debugPrint('[DETAIL LOAD] Loaded tournament with participants: ${tournament?.participants}');
    _renderContent();
  }

  void _startRefreshTimer() {
    _refreshTimer = async_tools.Timer.periodic(const Duration(seconds: 2), (_) async {
      final game = findGame() as TicTacToeGame?;
      final activeId = game?.activeTournamentId ?? tournamentId;
      if (activeId.isEmpty) return;

      debugPrint('[POLL] Polling tournament $activeId, current has ${tournament?.participants.length} participants');
      final updated = await tournamentService.getTournament(activeId);
      if (updated != null && updated.participants.toString() != tournament?.participants.toString()) {
        debugPrint('[POLL] Participant data changed! Old: ${tournament?.participants}, New: ${updated.participants}');
        tournament = updated;
        _renderContent();
      }
    });
  }

  @override
  Future<void> onRemove() async {
    _refreshTimer?.cancel();
    super.onRemove();
  }

  void _renderContent() {
    final game = findGame()!;
    final size = game.size;
    for (final component in _content) {
      component.removeFromParent();
    }
    _content.clear();
    final current = tournament;
    if (current == null) {
      _addContent(_label('TOURNAMENT NOT FOUND', Vector2(size.x / 2, size.y / 2), 16, Anchor.center));
      return;
    }

    _addContent(_label(current.name.toUpperCase(), Vector2(size.x / 2, 38), 22, Anchor.center, bold: true));
    _addContent(_DashboardTab(
      label: 'LEADERBOARD',
      position: Vector2(12, 72),
      size: Vector2(size.x / 2 - 18, 42),
      active: _activeTab == 0,
      onPressed: () { _activeTab = 0; _renderContent(); },
    ));
    _addContent(_DashboardTab(
      label: 'MATCH CENTER',
      position: Vector2(size.x / 2 + 6, 72),
      size: Vector2(size.x / 2 - 18, 42),
      active: _activeTab == 1,
      onPressed: () { _activeTab = 1; _renderContent(); },
    ));

    if (_activeTab == 0) {
      _renderLeaderboard(current, size);
    } else {
      _renderMatchCenter(current, size);
    }

    _addContent(ButtonComponent(
      label: 'BACK',
      position: Vector2(size.x / 2, size.y - 42),
      size: Vector2(min(size.x - 40, 180), 40),
      theme: ThemeStore.current,
      onPressed: () => (game as TicTacToeGame).router.pushReplacementNamed('tournaments'),
    ));
  }

  TextComponent _label(String text, Vector2 position, double fontSize, Anchor anchor, {bool bold = false}) {
    return TextComponent(
      text: text,
      position: position,
      anchor: anchor,
      textRenderer: TextPaint(style: TextStyle(
        color: ThemeStore.current.contrastColor,
        fontSize: fontSize,
        fontWeight: bold ? FontWeight.bold : FontWeight.normal,
      )),
    );
  }

  void _addContent(Component component) {
    _content.add(component);
    add(component);
  }

  void _renderLeaderboard(Tournament current, Vector2 size) {
    final wins = _winsByPlayer(current.bracket);
    final rows = current.participants.map((uid) => MapEntry(uid, wins[uid] ?? 0)).toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    _addContent(_DashboardPanel(
      position: Vector2(14, 132),
      size: Vector2(size.x - 28, size.y - 196),
      title: 'TOURNAMENT LEADERBOARD',
      childBuilder: (canvas, panelSize) {
        for (var index = 0; index < rows.length && index < 8; index++) {
          final rowY = 48.0 + index * 42;
          canvas.drawRRect(
            RRect.fromRectAndRadius(Rect.fromLTWH(12, rowY, panelSize.x - 24, 34), const Radius.circular(6)),
            Paint()..color = index == 0
                ? const Color(0xFFFFC857).withValues(alpha: 0.22)
                : ThemeStore.current.buttonBase.withValues(alpha: 0.35),
          );
          _paintText(canvas, '${index + 1}', 24, rowY + 8, 14);
          final name = rows[index].key.length > 8 ? rows[index].key.substring(0, 8) : rows[index].key;
          _paintText(canvas, name.toUpperCase(), 54, rowY + 8, 12);
          _paintText(canvas, '${rows[index].value} W', panelSize.x - 58, rowY + 8, 11);
        }
        if (rows.isEmpty) _paintText(canvas, 'PLAYERS APPEAR HERE WHEN THE TOURNAMENT STARTS', 16, 64, 10);
      },
    ));
  }

  void _renderMatchCenter(Tournament current, Vector2 size) {
    final next = userUid == null ? null : BracketService.getNextMatchForParticipant(current.bracket, userUid!);
    _addContent(_DashboardPanel(
      position: Vector2(14, 132),
      size: Vector2(size.x - 28, size.y - 196),
      title: 'MATCH CENTER',
      childBuilder: (canvas, panelSize) {
        _paintText(canvas, 'STATUS', 16, 56, 10, ThemeStore.current.contrastColor.withValues(alpha: 0.6));
        _paintText(canvas, current.status.name.toUpperCase(), 16, 76, 18, _statusColor(current.status));
        _paintText(canvas, 'PLAYERS', panelSize.x / 2, 56, 10, ThemeStore.current.contrastColor.withValues(alpha: 0.6));
        _paintText(canvas, '${current.participants.length}/${current.maxParticipants}', panelSize.x / 2, 76, 18);
        _paintText(canvas, 'INVITE CODE', 16, 116, 10, ThemeStore.current.contrastColor.withValues(alpha: 0.6));
        _paintText(canvas, current.inviteCode ?? 'OFFICIAL', 16, 138, 18);
        _paintText(canvas, 'NEXT MATCH', 16, 180, 10, ThemeStore.current.contrastColor.withValues(alpha: 0.6));
        _paintText(canvas, next == null ? 'WAITING FOR BRACKET ASSIGNMENT' : 'ROUND ${next['round']}  MATCH ${(next['position'] as int) + 1}', 16, 202, 13);
      },
    ));

    final bool showOpenMatch = current.status == TournamentStatus.active &&
        next != null &&
        (next['player1'] == userUid || next['player2'] == userUid);

    if (showOpenMatch) {
      _addContent(ButtonComponent(
        label: 'PLAY MATCH',
        position: Vector2(size.x / 2, size.y - 132),
        size: Vector2(min(size.x - 50, 220), 44),
        theme: ThemeStore.current,
        onPressed: () => (findGame() as TicTacToeGame).router.pushReplacementNamed('tournament_match_play'),
      ));
    } else if (userUid == current.createdBy &&
      current.status == TournamentStatus.waiting &&
      current.type == TournamentType.private &&
      current.participants.length >= 2) {
      _addContent(ButtonComponent(
        label: isStarting ? 'STARTING...' : 'START TOURNAMENT',
        position: Vector2(size.x / 2, size.y - 132),
        size: Vector2(min(size.x - 50, 240), 44),
        theme: ThemeStore.current,
        onPressed: isStarting ? () {} : _startTournament,
      ));
      _addContent(ButtonComponent(
        label: 'CANCEL TOURNAMENT',
        position: Vector2(size.x / 2, size.y - 82),
        size: Vector2(min(size.x - 50, 240), 38),
        theme: ThemeStore.current,
        onPressed: _confirmCancelTournament,
      ));
    } else if (userUid == current.createdBy &&
      current.status == TournamentStatus.waiting &&
      current.type == TournamentType.private &&
      current.participants.length < 2) {
      _addContent(ButtonComponent(
        label: 'NEED 2 PLAYERS TO START',
        position: Vector2(size.x / 2, size.y - 132),
        size: Vector2(min(size.x - 50, 240), 44),
        theme: ThemeStore.current,
        onPressed: () {},
      ));
      _addContent(ButtonComponent(
        label: 'CANCEL TOURNAMENT',
        position: Vector2(size.x / 2, size.y - 82),
        size: Vector2(min(size.x - 50, 240), 38),
        theme: ThemeStore.current,
        onPressed: _confirmCancelTournament,
      ));
    }
  }

  Map<String, int> _winsByPlayer(Map<String, dynamic> bracket) {
    final wins = <String, int>{};
    for (final value in bracket.values) {
      if (value is List) {
        for (final match in value.whereType<Map>()) {
          final winner = match['winner']?.toString();
          if (winner != null && winner.isNotEmpty) wins[winner] = (wins[winner] ?? 0) + 1;
        }
      }
    }
    return wins;
  }

  void _paintText(Canvas canvas, String text, double x, double y, double fontSize, [Color? color]) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: TextStyle(
        color: color ?? ThemeStore.current.contrastColor,
        fontSize: fontSize,
        fontWeight: FontWeight.bold,
      )),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: 300);
    painter.paint(canvas, Offset(x, y));
  }

  Future<void> _startTournament() async {
    if (tournament == null) return;
    isStarting = true;
    final success = await tournamentService.startTournament(tournamentId);
    if (success) tournament = await tournamentService.getTournament(tournamentId);
    isStarting = false;
    if (!success) {
      final game = findGame();
      if (game is TicTacToeGame) {
        game.showTransientMessage(
          userUid == tournament?.createdBy
              ? 'Add at least one more player before starting'
              : 'Only the tournament creator can start this tournament',
        );
      }
    }
    _renderContent();
  }

  void _confirmCancelTournament() {
    final game = findGame();
    if (game is! TicTacToeGame) return;
    final activeRoute = game.router.children.isEmpty
      ? game
      : game.router.children.last;
    activeRoute.add(
      ConfirmationOverlay(
        theme: ThemeStore.current,
        message: 'Cancel this waiting tournament?\nPlayers will be returned to the lobby.',
        onYes: _cancelTournament,
        onNo: () {},
      ),
    );
  }

  Future<void> _cancelTournament() async {
    final success = await tournamentService.cancelTournament(tournamentId);
    final game = findGame();
    if (game is TicTacToeGame) {
      if (success) {
        game.showTransientMessage('Tournament cancelled');
        game.router.pushReplacementNamed('tournaments');
      } else {
        game.showTransientMessage('Tournament could not be cancelled');
      }
    }
  }

  Color _statusColor(TournamentStatus status) {
    switch (status) {
      case TournamentStatus.waiting: return const Color(0xFFFFB347);
      case TournamentStatus.active: return const Color(0xFF90EE90);
      case TournamentStatus.completed: return const Color(0xFF87CEEB);
      case TournamentStatus.cancelled: return const Color(0xFFFF6B6B);
    }
  }
}

class _DashboardTab extends PositionComponent with TapCallbacks {
  final String label;
  final bool active;
  final VoidCallback onPressed;

  _DashboardTab({required this.label, required Vector2 position, required Vector2 size, required this.active, required this.onPressed})
      : super(position: position, size: size, anchor: Anchor.topLeft);

  @override
  void render(Canvas canvas) {
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(0, 0, size.x, size.y), const Radius.circular(8)), Paint()..color = active ? ThemeStore.current.buttonHighlight : ThemeStore.current.buttonBase.withValues(alpha: 0.45));
    final painter = TextPainter(text: TextSpan(text: label, style: TextStyle(color: ThemeStore.current.contrastColor, fontSize: 12, fontWeight: FontWeight.bold)), textDirection: TextDirection.ltr)..layout(maxWidth: size.x - 12);
    painter.paint(canvas, Offset((size.x - painter.width) / 2, (size.y - painter.height) / 2));
  }

  @override
  void onTapDown(TapDownEvent event) => onPressed();
}

class _DashboardPanel extends PositionComponent {
  final String title;
  final void Function(Canvas, Vector2) childBuilder;

  _DashboardPanel({required Vector2 position, required Vector2 size, required this.title, required this.childBuilder})
      : super(position: position, size: size, anchor: Anchor.topLeft);

  @override
  void render(Canvas canvas) {
    final rect = RRect.fromRectAndRadius(Rect.fromLTWH(0, 0, size.x, size.y), const Radius.circular(12));
    canvas.drawRRect(rect, Paint()..color = ThemeStore.current.buttonBase.withValues(alpha: 0.18));
    canvas.drawRRect(rect, Paint()..color = ThemeStore.current.gridColor.withValues(alpha: 0.35)..style = PaintingStyle.stroke..strokeWidth = 1.2);
    final titlePainter = TextPainter(text: TextSpan(text: title, style: TextStyle(color: ThemeStore.current.contrastColor, fontSize: 13, fontWeight: FontWeight.bold)), textDirection: TextDirection.ltr)..layout(maxWidth: size.x - 24);
    titlePainter.paint(canvas, const Offset(12, 16));
    childBuilder(canvas, size);
  }
}
