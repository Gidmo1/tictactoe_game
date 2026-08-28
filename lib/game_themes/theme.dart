import 'dart:ui' as ui;

import 'package:flame/sprite.dart';
import 'package:flutter/material.dart' show Color;

/// A swappable visual identity for the game board and symbols.
///
/// Everything in a theme is drawn procedurally from small design parameters
/// (colors, stroke thickness, glow…), so there are **no per-design PNG assets**.
/// A new shop skin is just a new [GameTheme] preset in [GameThemes.all].
class GameTheme {
  final String id;
  final String name;

  // Symbols (X / O)
  final Color xColor;
  final Color oColor;
  final double strokeWidth; // relative to the cell: 0.0–0.3
  final bool glow;

  // Board
  final Color gridColor;
  final Color boardBackground;

  // Buttons
  final Color buttonBase;
  final Color buttonHighlight;
  final Color textColor;

  GameTheme({
    required this.id,
    required this.name,
    required this.xColor,
    required this.oColor,
    this.strokeWidth = 0.14,
    this.glow = false,
    required this.gridColor,
    required this.boardBackground,
    required this.buttonBase,
    required this.buttonHighlight,
    required this.textColor,
  });

  // Caches so we don't re-rasterize the same symbol/button repeatedly.
  final Map<String, Future<Sprite>> _symbolCache = {};
  final Map<String, Future<Sprite>> _buttonCache = {};

  Color _markColor(String symbol) => symbol == 'X' ? xColor : oColor;

  /// Renders the given symbol ('X' or 'O') as a square [Sprite] of [size] px.
  Future<Sprite> symbolSprite(
    String symbol,
    double size, {
    double pixelRatio = 1,
  }) {
    final key = '$symbol-${size.round()}-${pixelRatio.toStringAsFixed(1)}';
    return _symbolCache.putIfAbsent(
      key,
      () => _renderSymbol(symbol, size, pixelRatio),
    );
  }

  Future<Sprite> _renderSymbol(
    String symbol,
    double size,
    double pixelRatio,
  ) async {
    final side = (size * pixelRatio).round();
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    canvas.scale(pixelRatio);

    final pad = size * 0.14;
    final span = size - pad * 2;
    final stroke = span * strokeWidth;
    final color = _markColor(symbol);

    final paint = ui.Paint()
      ..color = color
      ..style = ui.PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = ui.StrokeCap.round;

    if (glow) {
      final glowPaint = ui.Paint()
        ..color = color.withValues(alpha: 0.55)
        ..style = ui.PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = ui.StrokeCap.round
        ..maskFilter = ui.MaskFilter.blur(ui.BlurStyle.normal, stroke * 0.7);
      _drawSymbolShape(canvas, symbol, pad, span, glowPaint);
    }

    _drawSymbolShape(canvas, symbol, pad, span, paint);

    final image = await recorder.endRecording().toImage(side, side);
    return Sprite(image);
  }

  void _drawSymbolShape(
    ui.Canvas canvas,
    String symbol,
    double pad,
    double span,
    ui.Paint paint,
  ) {
    if (symbol == 'X') {
      canvas.drawLine(
        ui.Offset(pad, pad),
        ui.Offset(pad + span, pad + span),
        paint,
      );
      canvas.drawLine(
        ui.Offset(pad + span, pad),
        ui.Offset(pad, pad + span),
        paint,
      );
    } else {
      canvas.drawCircle(
        ui.Offset(pad + span / 2, pad + span / 2),
        span / 2,
        paint,
      );
    }
  }

  /// Renders a rounded, gradient "chip" button of [width] x [height] px.
  Future<Sprite> buttonSprite(double width, double height) {
    final key = '${width.round()}x${height.round()}';
    return _buttonCache.putIfAbsent(key, () => _renderButton(width, height));
  }

  Future<Sprite> _renderButton(double width, double height) async {
    final w = width;
    final h = height;
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);

    final radius = ui.Radius.circular((w < h ? w : h) * 0.22);
    final rrect = ui.RRect.fromRectAndRadius(
      ui.Rect.fromLTWH(0, 0, w, h),
      radius,
    );

    final fill = ui.Paint()
      ..shader = ui.Gradient.linear(ui.Offset(0, 0), ui.Offset(0, h), [
        buttonBase,
        buttonHighlight,
      ]);
    canvas.drawRRect(rrect, fill);

    // Subtle border to keep the chip readable on bright boards.
    final borderPaint = ui.Paint()
      ..color = gridColor.withValues(alpha: 0.35)
      ..style = ui.PaintingStyle.stroke
      ..strokeWidth = 1.2;
    canvas.drawRRect(rrect, borderPaint);

    final image = await recorder.endRecording().toImage(w.round(), h.round());
    return Sprite(image);
  }

  /// Returns black or white depending on how dark/light [boardBackground] is.
  Color get contrastColor {
    final l =
        boardBackground.r * 0.299 +
        boardBackground.g * 0.587 +
        boardBackground.b * 0.114;
    return l > 0.5 ? const Color(0xFF000000) : const Color(0xFFFFFFFF);
  }
}

/// The built-in, shipped skins. The Identity Shop later just appends here.
class GameThemes {
  static final classic = GameTheme(
    id: 'classic',
    name: 'Classic',
    xColor: Color(0xFF1565C0),
    oColor: Color(0xFFC62828),
    gridColor: Color(0xFFB8A36A),
    boardBackground: Color(0xFF18212B),
    buttonBase: Color(0xFF263746),
    buttonHighlight: Color(0xFF385267),
    textColor: Color(0xFFE8EDF2),
  );

  static final neonPulse = GameTheme(
    id: 'neon',
    name: 'Neon Pulse',
    xColor: Color(0xFF00FFD1),
    oColor: Color(0xFFFF3DAC),
    strokeWidth: 0.12,
    glow: true,
    gridColor: Color(0xFFB3E5FF),
    boardBackground: Color(0xFF0A1220),
    buttonBase: Color(0xFF1B2A4A),
    buttonHighlight: Color(0xFF3B5B9A),
    textColor: Color(0xFFFFFFFF),
  );

  static final royal = GameTheme(
    id: 'royal',
    name: 'Royal',
    xColor: Color(0xFFFFD54F),
    oColor: Color(0xFFB39DDB),
    strokeWidth: 0.18,
    gridColor: Color(0xFFE6C87A),
    boardBackground: Color(0xFF3E2723),
    buttonBase: Color(0xFF4E342E),
    buttonHighlight: Color(0xFF795548),
    textColor: Color(0xFFFFFFFF),
  );

  static final emerald = GameTheme(
    id: 'emerald',
    name: 'Emerald',
    xColor: Color(0xFF4DB6AC),
    oColor: Color(0xFF81C784),
    strokeWidth: 0.16,
    glow: true,
    gridColor: Color(0xFFA5D6A7),
    boardBackground: Color(0xFF1B2A1B),
    buttonBase: Color(0xFF2E4E2E),
    buttonHighlight: Color(0xFF4E7E4E),
    textColor: Color(0xFFFFFFFF),
  );

  static final List<GameTheme> all = [classic, neonPulse, royal, emerald];

  static GameTheme byId(String id) =>
      all.firstWhere((t) => t.id == id, orElse: () => classic);
}
