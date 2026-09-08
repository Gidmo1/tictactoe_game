import 'dart:math';

import 'package:flame/components.dart';
import 'package:flutter/material.dart' hide Route;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tictactoe_game/components/button.dart';
import 'package:tictactoe_game/game_themes/theme_store.dart';
import 'package:tictactoe_game/models/tournament.dart';
import 'package:tictactoe_game/service/tournament_service.dart';
import 'package:tictactoe_game/tictactoe.dart';

class JoinTournamentScreen extends Component with HasGameReference<TicTacToeGame> {
  late TournamentService tournamentService;
  static const double _buttonHeight = 46.0;

  String inviteCode = '';
  String? errorMessage;
  bool isJoining = false;
  TextComponent? _inviteCodeDisplay;

  @override
  Future<void> onLoad() async {
    final gameRef = findGame()!;
    final canvasSize = gameRef.size;
    tournamentService = TournamentService();

    final panelWidth = min(canvasSize.x * 0.92, 420.0).toDouble();
    final panelX = (canvasSize.x - panelWidth) / 2;
    final centerX = canvasSize.x / 2;

    add(
      RectangleComponent(
        size: canvasSize,
        paint: Paint()..color = ThemeStore.current.boardBackground,
        priority: -1,
      ),
    );

    add(
      RectangleComponent(
        position: Vector2(panelX, 90),
        size: Vector2(panelWidth, canvasSize.y - 170),
        paint: Paint()..color = ThemeStore.current.buttonBase.withValues(alpha: 0.10),
      ),
    );

    add(
      TextComponent(
        text: 'JOIN TOURNAMENT',
        position: Vector2(centerX, 46),
        anchor: Anchor.center,
        textRenderer: TextPaint(
          style: TextStyle(
            color: ThemeStore.current.contrastColor,
            fontSize: 26,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );

    final labelY = 120.0;

    add(
      TextComponent(
        text: 'INVITE CODE',
        position: Vector2(panelX + 14, labelY),
        anchor: Anchor.topLeft,
        textRenderer: TextPaint(
          style: TextStyle(
            color: ThemeStore.current.contrastColor,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );

    _inviteCodeDisplay = TextComponent(
      text: inviteCode.isEmpty ? 'ENTER INVITE CODE' : inviteCode,
      position: Vector2(panelX + 14, labelY + 24),
      anchor: Anchor.topLeft,
      textRenderer: TextPaint(
        style: TextStyle(
          color: ThemeStore.current.contrastColor.withValues(alpha: 0.9),
          fontSize: 18,
          fontWeight: FontWeight.bold,
          letterSpacing: 3,
        ),
      ),
    );
    add(_inviteCodeDisplay!);

    final primaryButtonWidth = min(panelWidth - 28, 220.0);

    add(
      ButtonComponent(
        label: 'ENTER CODE',
        position: Vector2(centerX, 192),
        size: Vector2(primaryButtonWidth, 44),
        theme: ThemeStore.current,
        onPressed: () {
          final g = findGame() as TicTacToeGame;
          g.pendingTournamentInviteCode = inviteCode;
          g.onTournamentInviteSubmitted = (value) {
            inviteCode = value.trim().toUpperCase();
            errorMessage = null;
            _inviteCodeDisplay?.text = inviteCode.isEmpty ? 'ENTER INVITE CODE' : inviteCode;
          };
          g.overlays.add('tournament_code_input');
        },
      ),
    );

    final rowWidth = min(panelWidth, 320.0);
    final buttonWidth = (rowWidth - 12) / 2;
    final bottomY = canvasSize.y - 86;

    if (errorMessage != null) {
      add(
        TextComponent(
          text: errorMessage!,
          position: Vector2(centerX, 225),
          anchor: Anchor.center,
          textRenderer: TextPaint(
            style: TextStyle(
              color: const Color(0xFFFF6B6B),
              fontSize: 12,
            ),
          ),
        ),
      );
    }

    add(
      ButtonComponent(
        label: isJoining ? 'JOINING...' : 'JOIN',
        position: Vector2(centerX - rowWidth / 2 + 6 + buttonWidth / 2, bottomY + _buttonHeight / 2),
        size: Vector2(buttonWidth, _buttonHeight),
        theme: ThemeStore.current,
        onPressed: isJoining ? () {} : _joinTournament,
      ),
    );

    add(
      ButtonComponent(
        label: 'BACK',
        position: Vector2(centerX + 6 + buttonWidth / 2, bottomY + _buttonHeight / 2),
        size: Vector2(buttonWidth, _buttonHeight),
        theme: ThemeStore.current,
        onPressed: () {
          final router = (findGame() as dynamic).router;
          router?.pushReplacementNamed('tournaments');
        },
      ),
    );
  }

  Future<void> _joinTournament() async {
    if (inviteCode.isEmpty) {
      _showError('Please enter an invite code');
      return;
    }

    if (inviteCode.length != 6) {
      _showError('Invite code must be 6 characters');
      return;
    }

    isJoining = true;

    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        _showError('Not authenticated');
        isJoining = false;
        return;
      }

      final activeTourn = await tournamentService.getUserActiveTournament(user.id);
      if (activeTourn != null) {
        _showError('You are already in a tournament');
        isJoining = false;
        return;
      }

      final success = await tournamentService.joinTournament(
        inviteCode: inviteCode,
        userUid: user.id,
      );
      debugPrint('[JOIN SCREEN] Join returned success=$success');

      if (success) {
        Tournament? tourn;
        for (var attempt = 0; attempt < 5; attempt++) {
          await Future.delayed(const Duration(milliseconds: 250));
          tourn = await tournamentService.getTournamentByInviteCode(inviteCode);
          if (tourn != null && tourn.participants.contains(user.id)) {
            break;
          }
        }

        debugPrint('[JOIN SCREEN] After join, getTournamentByInviteCode returned participants: ${tourn?.participants}');
        if (tourn != null) {
          final gameRef = findGame() as dynamic;
          gameRef.activeTournamentId = tourn.id;
          debugPrint('[JOIN SCREEN] Navigating to detail screen for tournament ${tourn.id}');
          gameRef.openTournamentDetails(tourn.id);
        }
      } else {
        _showError(tournamentService.lastJoinError ?? 'Could not join tournament');
      }
    } catch (e) {
      _showError('Error: ${e.toString()}');
      debugPrint('Error joining tournament: $e');
    } finally {
      isJoining = false;
    }
  }

  void _showError(String message) {
    errorMessage = message;
    final game = findGame();
    if (game is TicTacToeGame) {
      game.showTransientMessage(message);
    }
  }
}
