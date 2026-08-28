import 'dart:math';
import 'package:flame/components.dart';

class BoardLayout {
  static final Vector2 defaultScreenSize = Vector2(360, 640);

  final Vector2 screenSize;
  final int gridSize;

  late final double cellWidth;
  late final double cellHeight;
  late final double boardX;
  late final double boardY;

  BoardLayout(this.screenSize, {this.gridSize = 3}) {
    final width = screenSize.x;
    final height = screenSize.y;

    final cellSize = min(width * 0.90 / gridSize, height * 0.50 / gridSize);
    cellWidth = cellSize;
    cellHeight = cellSize;
    boardX = (width - cellSize * gridSize) / 2;
    // Keep the header clear while leaving enough room for the largest board.
    boardY = max(height * 0.36, 210.0);
  }
}
