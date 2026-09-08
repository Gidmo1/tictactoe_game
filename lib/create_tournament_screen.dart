import 'dart:math';

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flutter/material.dart' hide Route;
import 'package:tictactoe_game/tictactoe.dart';
import 'package:tictactoe_game/models/tournament.dart';
import 'package:tictactoe_game/service/tournament_service.dart';
import 'package:tictactoe_game/board_layout.dart';
import 'package:tictactoe_game/game_themes/theme_store.dart';
import 'package:tictactoe_game/components/button.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CreateTournamentScreen extends Component with HasGameReference<TicTacToeGame> {
  late BoardLayout layout;
  late TournamentService tournamentService;
  static const double _contentPadding = 18.0;
  static const double _buttonHeight = 46.0;

  String tournamentName = '';
  String tournamentDescription = '';
  int maxParticipants = 4;
  BracketType bracketType = BracketType.singleElimination;
  GridSize gridSize = GridSize.small;
  bool isCreating = false;
  TextComponent? _nameDisplay;

  @override
  Future<void> onLoad() async {
    final gameRef = findGame()!;
    final canvasSize = gameRef.size;
    layout = BoardLayout(canvasSize);
    tournamentService = TournamentService();
    final panelWidth = min(canvasSize.x * 0.9, 420.0).toDouble();
    final panelX = (canvasSize.x - panelWidth) / 2;

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
        text: 'CREATE TOURNAMENT',
        position: Vector2(canvasSize.x / 2, 46),
        anchor: Anchor.center,
        textRenderer: TextPaint(
          style: TextStyle(
            color: ThemeStore.current.contrastColor,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );

    _addFormFields(canvasSize, panelX, panelWidth);
  }

  void _addFormFields(Vector2 canvasSize, double panelX, double panelWidth) {
    final centerX = canvasSize.x / 2;
    final fieldX = panelX + _contentPadding;
    double yOffset = 112.0;

    add(
      TextComponent(
        text: 'TOURNAMENT NAME',
        position: Vector2(fieldX, yOffset),
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
    yOffset += 22;

    _nameDisplay = TextComponent(
      text: tournamentName.isEmpty ? 'TAP TO SET NAME' : tournamentName,
      position: Vector2(fieldX, yOffset),
      anchor: Anchor.topLeft,
      textRenderer: TextPaint(
        style: TextStyle(
          color: ThemeStore.current.contrastColor.withValues(alpha: 0.9),
          fontSize: 15,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
    add(_nameDisplay!);
    yOffset += 44;

    add(
      ButtonComponent(
        label: 'SET NAME',
        position: Vector2(
          fieldX + (panelWidth - _contentPadding * 2) / 2,
          yOffset + 20,
        ),
        size: Vector2(panelWidth - _contentPadding * 2, 40),
        theme: ThemeStore.current,
        onPressed: () {
          final g = findGame() as TicTacToeGame;
          g.pendingTournamentName = tournamentName;
          g.onTournamentNameSubmitted = (value) {
            tournamentName = value.trim();
            _nameDisplay?.text = tournamentName.isEmpty ? 'TAP TO SET NAME' : tournamentName;
          };
          g.overlays.add('tournament_name_input');
        },
      ),
    );
    yOffset += 54;

    add(
      TextComponent(
        text: 'MAX PLAYERS',
        position: Vector2(fieldX, yOffset),
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
    yOffset += 26;

    final maxPlayerOptions = [2, 4, 8, 16];
    final optionWidth = (panelWidth - _contentPadding * 2 - 18) / maxPlayerOptions.length;
    final playerButtons = <_SelectButton>[];
    for (int i = 0; i < maxPlayerOptions.length; i++) {
      final count = maxPlayerOptions[i];
      final button = _SelectButton(
          label: '$count',
          isSelected: maxParticipants == count,
          position: Vector2(fieldX + i * (optionWidth + 6), yOffset),
          size: Vector2(optionWidth, 30),
          onPressed: () {
            maxParticipants = count;
            for (final option in playerButtons) {
              option.isSelected = option.label == '$count';
            }
          },
        );
      playerButtons.add(button);
      add(button);
    }
    yOffset += 42;

    add(
      TextComponent(
        text: 'GRID SIZE',
        position: Vector2(fieldX, yOffset),
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
    yOffset += 26;

    final gridOptionWidth = (panelWidth - _contentPadding * 2 - 12) / GridSize.values.length;
    final gridButtons = <_SelectButton>[];
    for (int i = 0; i < GridSize.values.length; i++) {
      final size = GridSize.values[i];
      final button = _SelectButton(
          label: _getGridSizeLabel(size),
          isSelected: gridSize == size,
          position: Vector2(fieldX + i * (gridOptionWidth + 4), yOffset),
          size: Vector2(gridOptionWidth, 30),
          onPressed: () {
            gridSize = size;
            for (final option in gridButtons) {
              option.isSelected = option.label == _getGridSizeLabel(size);
            }
          },
        );
      gridButtons.add(button);
      add(button);
    }

    final bottomY = canvasSize.y - 86;
    final rowWidth = panelWidth - 14;
    final buttonWidth = (rowWidth - 12) / 2;

    add(
      ButtonComponent(
        label: isCreating ? 'CREATING...' : 'CREATE',
        position: Vector2(centerX - rowWidth / 2 + 6 + buttonWidth / 2, bottomY + _buttonHeight / 2),
        size: Vector2(buttonWidth, _buttonHeight),
        theme: ThemeStore.current,
        onPressed: isCreating ? () {} : _createTournament,
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

  Future<void> _createTournament() async {
    if (tournamentName.isEmpty) {
      debugPrint('Tournament name is empty');
      return;
    }

    isCreating = true;

    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        debugPrint('User not authenticated');
        return;
      }

      final createdTournament = await tournamentService.createPrivateTournament(
        name: tournamentName,
        description: tournamentDescription,
        createdBy: user.id,
        maxParticipants: maxParticipants,
        bracketType: bracketType,
        gridSize: gridSize,
      );

      debugPrint('Tournament created successfully');
      final gameRef = findGame() as dynamic;
      gameRef.openTournamentDetails(createdTournament.id);
    } catch (e) {
      debugPrint('Error creating tournament: $e');
    } finally {
      isCreating = false;
    }
  }

  String _getGridSizeLabel(GridSize size) {
    switch (size) {
      case GridSize.small:
        return '3x3';
      case GridSize.medium:
        return '4x4';
      case GridSize.large:
        return '5x5';
    }
  }
}

class _SelectButton extends PositionComponent with TapCallbacks {
  final String label;
  bool isSelected;
  final VoidCallback onPressed;

  _SelectButton({
    required this.label,
    required this.isSelected,
    required Vector2 position,
    required Vector2 size,
    required this.onPressed,
  }) : super(position: position, size: size, anchor: Anchor.topLeft);

  @override
  void render(Canvas canvas) {
    final bgColor = isSelected
        ? ThemeStore.current.buttonHighlight
        : ThemeStore.current.buttonBase.withValues(alpha: 0.6);

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, size.x, size.y),
        const Radius.circular(6),
      ),
      Paint()..color = bgColor,
    );

    final textPainter = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(
          color: ThemeStore.current.contrastColor,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset((size.x - textPainter.width) / 2, (size.y - textPainter.height) / 2),
    );
  }

  @override
  void onTapDown(TapDownEvent event) {
    onPressed();
  }
}
