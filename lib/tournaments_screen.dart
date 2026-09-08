import 'dart:math';

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flutter/material.dart' hide Route;
import 'package:tictactoe_game/tictactoe.dart';
import 'package:tictactoe_game/models/tournament.dart';
import 'package:tictactoe_game/service/tournament_service.dart';
import 'package:tictactoe_game/board_layout.dart';
import 'package:tictactoe_game/game_themes/theme_store.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class TournamentsScreen extends Component with HasGameReference<TicTacToeGame> {
  late BoardLayout layout;
  late TournamentService tournamentService;
  
  int activeTabIndex = 0; // 0 = Private, 1 = Official
  List<Tournament> privateTournaments = [];
  List<Tournament> officialTournaments = [];
  bool _isLoading = true;
  double _refreshElapsed = 0;
  bool _refreshInProgress = false;

  @override
  void update(double dt) {
    super.update(dt);
    _refreshElapsed += dt;
    if (_refreshElapsed >= 2 && !_refreshInProgress) {
      _refreshElapsed = 0;
      _refreshInProgress = true;
      _loadTournaments().whenComplete(() => _refreshInProgress = false);
    }
  }

  @override
  Future<void> onLoad() async {
    final gameRef = findGame()!;
    final canvasSize = gameRef.size;
    layout = BoardLayout(canvasSize);
    tournamentService = TournamentService();

    // Background
    add(
      RectangleComponent(
        size: canvasSize,
        paint: Paint()..color = ThemeStore.current.boardBackground,
        priority: -1,
      ),
    );

    // Header
    add(
      TextComponent(
        text: 'TOURNAMENTS',
        position: Vector2(canvasSize.x / 2, 40),
        anchor: Anchor.center,
        textRenderer: TextPaint(
          style: TextStyle(
            color: ThemeStore.current.contrastColor,
            fontSize: 28,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );

    // Tab buttons
    _addTabButtons(canvasSize);

    // Load tournaments
    await _loadTournaments();
  }

  void _addTabButtons(Vector2 canvasSize) {
    const tabHeight = 40.0;
    const tabY = 80.0;
    final tabWidth = canvasSize.x / 2 - 20;

    // Private tab
    add(
      _TabButton(
        label: 'PRIVATE',
        position: Vector2(10, tabY),
        size: Vector2(tabWidth, tabHeight),
        isActive: activeTabIndex == 0,
        onPressed: () {
          activeTabIndex = 0;
          removeWhere((c) => c is _TabButton || c is _TournamentListView);
          _addTabButtons(canvasSize);
          _addTournamentList(canvasSize);
        },
      ),
    );

    // Official tab
    add(
      _TabButton(
        label: 'OFFICIAL',
        position: Vector2(canvasSize.x / 2 + 10, tabY),
        size: Vector2(tabWidth, tabHeight),
        isActive: activeTabIndex == 1,
        onPressed: () {
          activeTabIndex = 1;
          removeWhere((c) => c is _TabButton || c is _TournamentListView);
          _addTabButtons(canvasSize);
          _addTournamentList(canvasSize);
        },
      ),
    );
  }

  Future<void> _loadTournaments() async {
    try {
      privateTournaments = await tournamentService.getActivePrivateTournaments();
      officialTournaments = await tournamentService.getOfficialTournaments();
      _isLoading = false;
      
      final gameRef = findGame()!;
      removeWhere((c) => c is _TournamentListView);
      _addTournamentList(gameRef.size);
    } catch (e) {
      debugPrint('Error loading tournaments: $e');
      _isLoading = false;
    }
  }

  void _addTournamentList(Vector2 canvasSize) {
    removeWhere((c) => c is _TournamentListView || c is _ActionButton);
    final actionY = canvasSize.y - 76;
    final panelWidth = canvasSize.x - 20;

    add(
      _TournamentListView(
        tournaments: activeTabIndex == 0 ? privateTournaments : officialTournaments,
        tournamentType: activeTabIndex == 0 ? TournamentType.private : TournamentType.official,
        position: Vector2(10, 140),
        size: Vector2(panelWidth, canvasSize.y - 260),
        onTournamentTap: (tournament) {
          final gameRef = findGame() as dynamic;
          final userId = Supabase.instance.client.auth.currentUser?.id;
          if (tournament.type == TournamentType.official ||
              (userId != null && tournament.participants.contains(userId))) {
            gameRef.openTournamentDetails(tournament.id);
            return;
          }

          gameRef.pendingTournamentAccessId = tournament.id;
          gameRef.pendingTournamentInviteCode = '';
          gameRef.onTournamentInviteSubmitted = (value) async {
            final enteredCode = value.trim().toUpperCase();
            if (enteredCode != tournament.inviteCode?.toUpperCase()) {
              gameRef.showTransientMessage('Invalid tournament invite code');
              return;
            }
            final currentUser = Supabase.instance.client.auth.currentUser;
            if (currentUser == null) {
              gameRef.showTransientMessage('Sign in to join this tournament');
              return;
            }
            final service = TournamentService();
            final joined = await service.joinTournament(
              inviteCode: enteredCode,
              userUid: currentUser.id,
            );
            if (joined || tournament.participants.contains(currentUser.id)) {
              gameRef.openTournamentDetails(tournament.id);
            } else {
              gameRef.showTransientMessage(
                service.lastJoinError ?? 'Could not join this tournament',
              );
            }
          };
          gameRef.overlays.add('tournament_code_input');
        },
      ),
    );

    // Action buttons at bottom
    if (activeTabIndex == 0) {
      final buttonWidth = (panelWidth - 20) / 3;
      final startX = (canvasSize.x - (buttonWidth * 3 + 10)) / 2;

      add(
        _ActionButton(
          label: 'CREATE',
          position: Vector2(startX, actionY),
          size: Vector2(buttonWidth, 44),
          onPressed: () {
            final gameRef = findGame() as dynamic;
            gameRef.router.pushReplacementNamed('create_tournament');
          },
        ),
      );

      add(
        _ActionButton(
          label: 'JOIN',
          position: Vector2(startX + buttonWidth + 5, actionY),
          size: Vector2(buttonWidth, 44),
          onPressed: () {
            final gameRef = findGame() as dynamic;
            gameRef.router.pushReplacementNamed('join_tournament');
          },
        ),
      );

      add(
        _ActionButton(
          label: 'BACK',
          position: Vector2(startX + (buttonWidth + 5) * 2, actionY),
          size: Vector2(buttonWidth, 44),
          onPressed: () {
            final gameRef = findGame() as dynamic;
            gameRef.router.pushReplacementNamed('menu');
          },
        ),
      );
      return;
    }

    final backWidth = min(160.0, (canvasSize.x - 40) / 2);
    add(
      _ActionButton(
        label: 'BACK',
        position: Vector2(canvasSize.x / 2 - backWidth / 2, actionY),
        size: Vector2(backWidth, 44),
        onPressed: () {
          final gameRef = findGame() as dynamic;
          gameRef.router.pushReplacementNamed('menu');
        },
      ),
    );
  }
}

class _TabButton extends PositionComponent with TapCallbacks {
  final String label;
  final VoidCallback onPressed;
  final bool isActive;

  _TabButton({
    required this.label,
    required Vector2 position,
    required Vector2 size,
    required this.isActive,
    required this.onPressed,
  }) : super(position: position, size: size, anchor: Anchor.topLeft);

  @override
  void render(Canvas canvas) {
    final bgColor = isActive
        ? ThemeStore.current.buttonHighlight
        : ThemeStore.current.buttonBase.withValues(alpha: 0.5);
    
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, size.x, size.y),
        const Radius.circular(8),
      ),
      Paint()..color = bgColor,
    );

    final textPainter = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(
          color: ThemeStore.current.contrastColor,
          fontSize: 14,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(
        (size.x - textPainter.width) / 2,
        (size.y - textPainter.height) / 2,
      ),
    );
  }

  @override
  void onTapDown(TapDownEvent event) {
    onPressed();
  }
}

class _TournamentListView extends PositionComponent with TapCallbacks {
  final List<Tournament> tournaments;
  final TournamentType tournamentType;
  final Function(Tournament)? onTournamentTap;

  _TournamentListView({
    required this.tournaments,
    required this.tournamentType,
    required Vector2 position,
    required Vector2 size,
    this.onTournamentTap,
  }) : super(position: position, size: size, anchor: Anchor.topLeft);

  @override
  void render(Canvas canvas) {
    if (tournaments.isEmpty) {
      final emptyText = TextPainter(
        text: TextSpan(
          text: tournamentType == TournamentType.private
              ? 'No private tournaments.\nCreate or join one to get started!'
              : 'No official tournaments available.',
          style: TextStyle(
            color: ThemeStore.current.contrastColor.withValues(alpha: 0.7),
            fontSize: 12,
            height: 1.5,
          ),
        ),
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center,
      );
      emptyText.layout(maxWidth: size.x - 20);
      emptyText.paint(
        canvas,
        Offset(
          (size.x - emptyText.width) / 2,
          (size.y - emptyText.height) / 2,
        ),
      );
      return;
    }

    // Draw tournament list
    double yOffset = 0;
    for (final tournament in tournaments.take(5)) {
      final rect = Rect.fromLTWH(0, yOffset, size.x, 80);
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(8)),
        Paint()..color = ThemeStore.current.boardBackground.withValues(alpha: 0.8),
      );

      // Tournament name
      final namePainter = TextPainter(
        text: TextSpan(
          text: tournament.name,
          style: TextStyle(
            color: ThemeStore.current.contrastColor,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      namePainter.layout();
      namePainter.paint(canvas, Offset(10, yOffset + 8));

      // Participants
      final participantsPainter = TextPainter(
        text: TextSpan(
          text: '${tournament.participants.length}/${tournament.maxParticipants} Players',
          style: TextStyle(
            color: ThemeStore.current.contrastColor.withValues(alpha: 0.8),
            fontSize: 11,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      participantsPainter.layout();
      participantsPainter.paint(canvas, Offset(10, yOffset + 28));

      // Status
      final statusPainter = TextPainter(
        text: TextSpan(
          text: tournament.status.name.toUpperCase(),
          style: TextStyle(
            color: _getStatusColor(tournament.status),
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      statusPainter.layout();
      statusPainter.paint(canvas, Offset(10, yOffset + 48));

      yOffset += 90;
    }
  }

  @override
  void onTapDown(TapDownEvent event) {
    if (onTournamentTap == null || tournaments.isEmpty) return;

    final rowIndex = (event.localPosition.y ~/ 90);
    final rowOffset = event.localPosition.y - rowIndex * 90;
    if (rowIndex < 0 || rowIndex >= tournaments.length || rowIndex >= 5) {
      return;
    }
    if (rowOffset < 0 || rowOffset > 80) return;

    onTournamentTap!(tournaments[rowIndex]);
  }

  Color _getStatusColor(TournamentStatus status) {
    switch (status) {
      case TournamentStatus.waiting:
        return const Color(0xFFFFB347);
      case TournamentStatus.active:
        return const Color(0xFF90EE90);
      case TournamentStatus.completed:
        return const Color(0xFF87CEEB);
      case TournamentStatus.cancelled:
        return const Color(0xFFFF6B6B);
    }
  }
}

class _ActionButton extends PositionComponent with TapCallbacks {
  final String label;
  final VoidCallback onPressed;

  _ActionButton({
    required this.label,
    required Vector2 position,
    required Vector2 size,
    required this.onPressed,
  }) : super(position: position, size: size, anchor: Anchor.topLeft);

  @override
  void render(Canvas canvas) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, size.x, size.y),
        const Radius.circular(8),
      ),
      Paint()..color = ThemeStore.current.buttonHighlight,
    );

    final textPainter = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(
          color: ThemeStore.current.contrastColor,
          fontSize: 14,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(
        (size.x - textPainter.width) / 2,
        (size.y - textPainter.height) / 2,
      ),
    );
  }

  @override
  void onTapDown(TapDownEvent event) {
    onPressed();
  }
}
