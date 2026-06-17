import 'dart:math';
import 'package:flame/components.dart';

class BoardLayout {
  static final Vector2 defaultScreenSize = Vector2(360, 640);

  final Vector2 screenSize;

  late final double cellWidth;
  late final double cellHeight;
  late final double boardX;
  late final double boardY;

  BoardLayout(this.screenSize) {
    final width = screenSize.x;
    final height = screenSize.y;

    final cellSize = min(width * 0.28, height * 0.16);
    cellWidth = cellSize;
    cellHeight = cellSize;
    boardX = (width - cellSize * 3) / 2;
    boardY = max(height * 0.30, 80.0);
  }
}
