import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:tictactoe_game/models/tournament.dart';
import 'package:tictactoe_game/game_themes/theme_store.dart';

class BracketVisualization extends Component {
  final Tournament tournament;
  final double padding = 20;
  final double bracketWidth = 400;
  final double bracketHeight = 600;

  BracketVisualization({
    required this.tournament,
  }) : super();

  @override
  void render(Canvas canvas) {
    final bracket = tournament.bracket;
    if (bracket.isEmpty) {
      _renderPlaceholder(canvas);
      return;
    }

    // Get all rounds
    final rounds = <List<Map<String, dynamic>>>[];
    int roundNum = 1;
    while (bracket.containsKey('round_$roundNum')) {
      final roundMatches = List<Map<String, dynamic>>.from(
        bracket['round_$roundNum'] as List? ?? [],
      );
      rounds.add(roundMatches);
      roundNum++;
    }

    if (rounds.isEmpty) {
      _renderPlaceholder(canvas);
      return;
    }

    _renderBracket(canvas, rounds);
  }

  void _renderPlaceholder(Canvas canvas) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: 'Tournament not started',
        style: TextStyle(
          color: ThemeStore.current.contrastColor.withValues(alpha: 0.5),
          fontSize: 12,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(
        (bracketWidth - textPainter.width) / 2,
        (bracketHeight - textPainter.height) / 2,
      ),
    );
  }

  void _renderBracket(Canvas canvas, List<List<Map<String, dynamic>>> rounds) {
    const columnWidth = 90.0;
    const rowHeight = 60.0;
    double xOffset = padding;

    for (int roundIdx = 0; roundIdx < rounds.length; roundIdx++) {
      final matches = rounds[roundIdx];
      double yOffset = padding + (rowHeight / 2);

      // Calculate vertical spacing
      final spacingMultiplier = (1 << roundIdx).toDouble(); // 1, 2, 4, 8, ...
      final verticalGap = rowHeight * spacingMultiplier;

      for (int matchIdx = 0; matchIdx < matches.length; matchIdx++) {
        final match = matches[matchIdx];
        final yPos = yOffset + (matchIdx * verticalGap);

        _renderMatch(canvas, match, xOffset, yPos, columnWidth);

        // Draw line to next round
        if (roundIdx < rounds.length - 1) {
          _drawConnectorLine(canvas, match, xOffset, yPos, columnWidth);
        }
      }

      xOffset += columnWidth + 20;
    }
  }

  void _renderMatch(
    Canvas canvas,
    Map<String, dynamic> match,
    double x,
    double y,
    double width,
  ) {
    final height = 50.0;
    final rect = Rect.fromLTWH(x, y - height / 2, width, height);

    // Background
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(4)),
      Paint()
        ..color = match['completed'] == true
            ? ThemeStore.current.buttonHighlight.withValues(alpha: 0.7)
            : ThemeStore.current.buttonBase.withValues(alpha: 0.6),
    );

    // Border
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(4)),
      Paint()
        ..color = ThemeStore.current.contrastColor.withValues(alpha: 0.3)
        ..strokeWidth = 1
        ..style = PaintingStyle.stroke,
    );

    // Player 1
    if (match['player1'] != null) {
      final p1Text = TextPainter(
        text: TextSpan(
          text: (match['player1'] as String).substring(0, 6),
          style: TextStyle(
            color: match['winner'] == match['player1']
                ? const Color(0xFFFFD700) // Gold for winner
                : ThemeStore.current.contrastColor,
            fontSize: 10,
            fontWeight: match['winner'] == match['player1']
                ? FontWeight.bold
                : FontWeight.normal,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      p1Text.layout();
      p1Text.paint(canvas, Offset(x + 5, y - height / 2 + 5));
    }

    // VS
    if (match['player2'] != null) {
      final vsText = TextPainter(
        text: TextSpan(
          text: 'vs',
          style: TextStyle(
            color: ThemeStore.current.contrastColor.withValues(alpha: 0.5),
            fontSize: 8,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      vsText.layout();
      vsText.paint(
        canvas,
        Offset(x + width / 2 - vsText.width / 2, y - 5),
      );
    }

    // Player 2
    if (match['player2'] != null) {
      final p2Text = TextPainter(
        text: TextSpan(
          text: (match['player2'] as String).substring(0, 6),
          style: TextStyle(
            color: match['winner'] == match['player2']
                ? const Color(0xFFFFD700) // Gold for winner
                : ThemeStore.current.contrastColor,
            fontSize: 10,
            fontWeight: match['winner'] == match['player2']
                ? FontWeight.bold
                : FontWeight.normal,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      p2Text.layout();
      p2Text.paint(canvas, Offset(x + 5, y + height / 2 - 15));
    } else {
      // TBD if no player 2
      final tbdText = TextPainter(
        text: TextSpan(
          text: 'TBD',
          style: TextStyle(
            color: ThemeStore.current.contrastColor.withValues(alpha: 0.4),
            fontSize: 9,
            fontStyle: FontStyle.italic,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      tbdText.layout();
      tbdText.paint(canvas, Offset(x + 5, y + height / 2 - 15));
    }
  }

  void _drawConnectorLine(
    Canvas canvas,
    Map<String, dynamic> match,
    double x,
    double y,
    double width,
  ) {
    if (match['winner'] == null) return;

    final endX = x + width;
    final paint = Paint()
      ..color = ThemeStore.current.contrastColor.withValues(alpha: 0.3)
      ..strokeWidth = 1;

    // Horizontal line from match
    canvas.drawLine(
      Offset(endX, y),
      Offset(endX + 10, y),
      paint,
    );
  }
}
