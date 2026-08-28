import 'dart:math';

import 'package:flame/components.dart';
import 'package:flutter/painting.dart' show Paint;

import '../board_layout.dart';
import 'theme.dart';

/// Draws the themed 3×3 board (opaque backdrop + grid lines) as a set of
/// Flame [Component]s. Shared by every board so they all render identically.
///
/// The backdrop is opaque so it cleanly covers any grid baked into the
/// underlying play-screen art, keeping the *only* visible grid the themed one.
List<Component> themedBoardComponents(BoardLayout layout, GameTheme theme) {
  final pieces = <Component>[];
  final t = max(layout.cellWidth, layout.cellHeight) * 0.01;

  // Opaque board panel sized to the configured region (slightly oversized so it fully
  // hides the art grid beneath).
  pieces.add(
    RectangleComponent(
      size: Vector2(
        layout.cellWidth * layout.gridSize + t,
        layout.cellHeight * layout.gridSize + t,
      ),
      position: Vector2(layout.boardX - t / 2, layout.boardY - t / 2),
      paint: Paint()..color = theme.boardBackground,
    ),
  );

  // Grid lines at the exact cell boundaries.
  for (int i = 0; i <= layout.gridSize; i++) {
    final x = layout.boardX + i * layout.cellWidth;
    pieces.add(
      RectangleComponent(
        size: Vector2(t, layout.cellHeight * layout.gridSize),
        position: Vector2(x, layout.boardY),
        paint: Paint()..color = theme.gridColor,
      ),
    );
    final y = layout.boardY + i * layout.cellHeight;
    pieces.add(
      RectangleComponent(
        size: Vector2(layout.cellWidth * layout.gridSize, t),
        position: Vector2(layout.boardX, y),
        paint: Paint()..color = theme.gridColor,
      ),
    );
  }

  return pieces;
}
