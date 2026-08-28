import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame_audio/flame_audio.dart';
import 'package:flutter/material.dart';

import 'components/button.dart';
import 'game_themes/theme.dart';
import 'game_themes/theme_store.dart';
import 'tictactoe.dart';
import 'settings_screen.dart';
import 'vs_computer_match_config.dart';

class VsComputerSetupScreen extends Component
    with HasGameReference<TicTacToeGame> {
  GameTheme get theme => ThemeStore.current;
  int _difficulty = 2;
  int _rounds = 3;
  String _humanPlayer = 'X';
  int _gridSize = 3;
  TextComponent? _summary;
  final List<Component> _controls = [];
  bool _refreshingTheme = false;
  String? _builtThemeId;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    _buildScreen();
  }

  @override
  void onMount() {
    super.onMount();
    ThemeStore.addListener(refreshTheme);
    if (_builtThemeId != null && _builtThemeId != theme.id) {
      refreshTheme();
    }
  }

  @override
  void onRemove() {
    ThemeStore.removeListener(refreshTheme);
    super.onRemove();
  }

  void refreshTheme() {
    if (_refreshingTheme) return;
    _refreshingTheme = true;
    for (final child in children.toList()) {
      child.removeFromParent();
    }
    _controls.clear();
    _summary = null;
    _buildScreen();
    _refreshingTheme = false;
  }

  void _buildScreen() {
    final screen = game.size;
    _builtThemeId = theme.id;
    add(
      RectangleComponent(
        size: screen,
        paint: Paint()..color = theme.boardBackground,
      ),
    );
    add(
      TextComponent(
        text: 'VS COMPUTER',
        position: Vector2(screen.x / 2, 64),
        anchor: Anchor.center,
        textRenderer: TextPaint(
          style: TextStyle(
            color: theme.contrastColor,
            fontSize: 26,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );

    _addSection('DIFFICULTY', 126);
    _addStepper(
      label: () => _difficultyLabel(),
      options: const ['RELAXED', 'BALANCED', 'EXPERT'],
      value: () => _difficulty - 1,
      y: 178,
      onChanged: (index) {
        _difficulty = index + 1;
        _refreshSummary();
      },
    );

    _addSection('GRID SIZE', 226);
    _addStepper(
      label: () => '$_gridSize X $_gridSize',
      options: List.generate(8, (index) => '${index + 3} X ${index + 3}'),
      value: () => _gridSize - 3,
      y: 278,
      onChanged: (index) {
        _gridSize = index + 3;
        _refreshSummary();
      },
    );

    _addSection('ROUNDS', 326);
    _addStepper(
      label: () => '$_rounds',
      options: const ['1', '3', '5'],
      value: () => [1, 3, 5].indexOf(_rounds),
      y: 378,
      onChanged: (index) {
        _rounds = [1, 3, 5][index];
        _refreshSummary();
      },
    );

    _addSection('CHARACTER', 426);
    _addStepper(
      label: () => _humanPlayer,
      options: const ['X', 'O'],
      value: () => _humanPlayer == 'X' ? 0 : 1,
      y: 478,
      onChanged: (index) {
        _humanPlayer = index == 0 ? 'X' : 'O';
        _refreshSummary();
      },
    );

    _summary = TextComponent(
      text: '',
      position: Vector2(screen.x / 2, screen.y - 82),
      anchor: Anchor.center,
      textRenderer: TextPaint(
        style: TextStyle(
          color: theme.gridColor,
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
    add(_summary!);
    _refreshSummary();

    add(
      ButtonComponent(
        label: 'START GAME',
        position: Vector2(screen.x / 2 + 54, screen.y - 36),
        size: Vector2(190, 46),
        theme: theme,
        onPressed: _startGame,
      ),
    );
    add(
      ButtonComponent(
        label: 'BACK',
        position: Vector2(screen.x / 2 - 95, screen.y - 36),
        size: Vector2(82, 34),
        theme: theme,
        onPressed: () => game.router.pushReplacementNamed('menu'),
      ),
    );
  }

  void _addSection(String label, double y) {
    add(
      TextComponent(
        text: label,
        position: Vector2(24, y),
        textRenderer: TextPaint(
          style: TextStyle(
            color: theme.gridColor,
            fontSize: 15,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
          ),
        ),
      ),
    );
  }

  void _addChoiceRow({
    required List<String> labels,
    required int Function() selected,
    required double top,
    required void Function(int) onSelected,
  }) {
    final gap = 8.0;
    final width =
        (game.size.x - 48 - gap * (labels.length - 1)) / labels.length;
    for (var index = 0; index < labels.length; index++) {
      final button = _SetupChoiceButton(
        label: labels[index],
        theme: theme,
        selected: () => selected() == index,
        position: Vector2(24 + index * (width + gap) + width / 2, top + 22),
        size: Vector2(width, 44),
        onPressed: () => onSelected(index),
      );
      _controls.add(button);
      add(button);
    }
  }

  void _addChoiceGrid({
    required List<String> labels,
    required int Function() selected,
    required double top,
    required void Function(int) onSelected,
  }) {
    const columns = 4;
    const rowHeight = 38.0;
    const rowGap = 6.0;
    final gap = 6.0;
    final width = (game.size.x - 48 - gap * (columns - 1)) / columns;
    for (var index = 0; index < labels.length; index++) {
      final column = index % columns;
      final row = index ~/ columns;
      final button = _SetupChoiceButton(
        label: labels[index],
        theme: theme,
        selected: () => selected() == index,
        position: Vector2(
          24 + column * (width + gap) + width / 2,
          top + row * (rowHeight + rowGap) + rowHeight / 2,
        ),
        size: Vector2(width, rowHeight),
        onPressed: () => onSelected(index),
      );
      _controls.add(button);
      add(button);
    }
  }

  void _addStepper({
    required String Function() label,
    required List<String> options,
    required int Function() value,
    required double y,
    required void Function(int) onChanged,
  }) {
    final stepper = _SetupStepper(
      label: label,
      options: options,
      value: value,
      theme: theme,
      position: Vector2(game.size.x / 2, y),
      size: Vector2(math.min(game.size.x - 48, 230), 48),
      onChanged: onChanged,
    );
    _controls.add(stepper);
    add(stepper);
  }

  void _refreshSummary() {
    _summary?.text =
        '${_difficultyLabel()}  |  $_gridSize X $_gridSize  |  $_rounds ROUNDS  |  $_humanPlayer';
  }

  String _difficultyLabel() {
    if (_difficulty == 1) return 'RELAXED';
    if (_difficulty == 2) return 'BALANCED';
    return 'EXPERT';
  }

  void _startGame() {
    final config = VsComputerMatchConfig(
      difficulty: _difficulty,
      rounds: _rounds,
      humanPlayer: _humanPlayer,
      gridSize: _gridSize,
    );
    game.startVsComputer(config);
  }
}

class _SetupChoiceButton extends PositionComponent with TapCallbacks {
  final String label;
  final GameTheme theme;
  final bool Function() selected;
  final VoidCallback onPressed;

  _SetupChoiceButton({
    required this.label,
    required this.theme,
    required this.selected,
    required Vector2 position,
    required Vector2 size,
    required this.onPressed,
  }) : super(position: position - size / 2, size: size);

  @override
  void render(Canvas canvas) {
    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.x, size.y),
      const Radius.circular(8),
    );
    canvas.drawRRect(
      rect,
      Paint()..color = selected() ? theme.buttonHighlight : theme.buttonBase,
    );
    canvas.drawRRect(
      rect,
      Paint()
        ..color = selected()
            ? theme.gridColor
            : theme.gridColor.withValues(alpha: 0.45)
        ..style = PaintingStyle.stroke
        ..strokeWidth = selected() ? 2.5 : 1.2,
    );
    TextPaint(
      style: TextStyle(
        color: theme.textColor,
        fontSize: 15,
        fontWeight: FontWeight.bold,
      ),
    ).render(canvas, label, size / 2, anchor: Anchor.center);
  }

  @override
  void onTapDown(TapDownEvent event) {
    if (SettingsScreen.buttonSoundOn) {
      FlameAudio.play('button.wav');
    }
    onPressed();
  }
}

class _SetupStepper extends PositionComponent with TapCallbacks {
  final String Function() label;
  final List<String> options;
  final int Function() value;
  final GameTheme theme;
  final void Function(int) onChanged;

  _SetupStepper({
    required this.label,
    required this.options,
    required this.value,
    required this.theme,
    required Vector2 position,
    required Vector2 size,
    required this.onChanged,
  }) : super(position: position - size / 2, size: size) {
    priority = 1000;
  }

  @override
  bool containsLocalPoint(Vector2 point) {
    return point.x >= 0 &&
        point.x <= size.x &&
        point.y >= 0 &&
        point.y <= size.y;
  }

  @override
  void render(Canvas canvas) {
    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.x, size.y),
      const Radius.circular(8),
    );
    canvas.drawRRect(rect, Paint()..color = theme.buttonBase);
    canvas.drawRRect(
      rect,
      Paint()
        ..color = theme.gridColor.withValues(alpha: 0.65)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );
    final arrowPaint = TextPaint(
      style: TextStyle(
        color: theme.gridColor,
        fontSize: 28,
        fontWeight: FontWeight.bold,
      ),
    );
    arrowPaint.render(
      canvas,
      '<',
      Vector2(28, size.y / 2),
      anchor: Anchor.center,
    );
    arrowPaint.render(
      canvas,
      '>',
      Vector2(size.x - 28, size.y / 2),
      anchor: Anchor.center,
    );
    TextPaint(
      style: TextStyle(
        color: theme.textColor,
        fontSize: 18,
        fontWeight: FontWeight.bold,
      ),
    ).render(canvas, label(), size / 2, anchor: Anchor.center);
  }

  @override
  void onTapDown(TapDownEvent event) {
    if (SettingsScreen.buttonSoundOn) {
      FlameAudio.play('button.wav');
    }
    final direction = event.localPosition.x < size.x / 2 ? -1 : 1;
    final next = (value() + direction + options.length) % options.length;
    onChanged(next);
    event.continuePropagation = false;
  }
}
