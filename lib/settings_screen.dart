import 'dart:ui' as ui;
import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flame/events.dart';
import 'package:flame_audio/flame_audio.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tictactoe_game/components/button.dart';
import 'package:tictactoe_game/game_themes/theme.dart';
import 'package:tictactoe_game/game_themes/theme_store.dart';
import 'package:tictactoe_game/tictactoe.dart';

/// Shared border constants for gold/wooden theme decor on overlay widgets.
class OverlayBorder {
  static const Color gold = Color(0xFFD4AF37);
  static const Color goldLight = Color(0xFFF0D060);
  static const Color goldDark = Color(0xFF996515);
  static const Color wood = Color(0xFF6B3A2A);
  static const Color woodLight = Color(0xFF8B5E3C);

  static BoxDecoration ornateBorder({double radius = 12}) {
    return BoxDecoration(
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: gold, width: 3),
      boxShadow: [
        BoxShadow(
          color: goldDark.withValues(alpha: 0.5),
          blurRadius: 8,
          spreadRadius: 1,
          offset: const Offset(0, 2),
        ),
        BoxShadow(
          color: goldLight.withValues(alpha: 0.3),
          blurRadius: 4,
          spreadRadius: 0,
          offset: const Offset(0, 0),
        ),
      ],
    );
  }

  static Paint goldStrokePaint(double strokeWidth) {
    return Paint()
      ..color = gold
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
  }

  static Paint woodFillPaint() {
    return Paint()
      ..color = woodLight.withValues(alpha: 0.2)
      ..style = PaintingStyle.fill;
  }
}

class SettingsScreen extends Component with HasGameReference<TicTacToeGame> {
  final String returnRoute;

  SettingsScreen({this.returnRoute = 'menu'});

  static bool buttonSoundOn = true;
  static bool gameSoundOn = true;

  late _ProceduralToggleButton _buttonToggle;
  late _ProceduralToggleButton _gameToggle;
  GameTheme get theme => ThemeStore.current;

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    // Background
    add(
      RectangleComponent(
        size: game.size,
        position: Vector2.zero(),
        paint: Paint()..color = theme.boardBackground,
      ),
    );

    // Title
    add(
      TextComponent(
        text: 'SETTINGS',
        anchor: Anchor.topCenter,
        position: Vector2(game.size.x / 2, 26),
        textRenderer: TextPaint(
          style: TextStyle(
            color: theme.contrastColor,
            fontSize: 28,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );

    // --- Panel background ---
    final panelX = 12.0;
    final panelY = 90.0;
    final panelW = game.size.x - 24;
    final panelH = 420.0;

    add(_PanelBackground(rect: Rect.fromLTWH(panelX, panelY, panelW, panelH)));

    // --- SECTION: AUDIO ---
    final sectionY = panelY + 16;
    add(
      TextComponent(
        text: 'AUDIO',
        anchor: Anchor.topLeft,
        position: Vector2(panelX + 16, sectionY),
        textRenderer: TextPaint(
          style: TextStyle(
            color: OverlayBorder.gold,
            fontSize: 16,
            fontWeight: FontWeight.bold,
            letterSpacing: 2,
          ),
        ),
      ),
    );

    // Sound effect toggle
    const buttonToggleY = 134.0;
    add(
      TextComponent(
        text: 'Sound',
        anchor: Anchor.centerLeft,
        position: Vector2(panelX + 16, buttonToggleY),
        textRenderer: TextPaint(
          style: TextStyle(color: theme.contrastColor, fontSize: 18),
        ),
      ),
    );

    _buttonToggle = _ProceduralToggleButton(
      position: Vector2(panelX + panelW - 30, buttonToggleY),
      initialOn: buttonSoundOn,
      onChanged: (val) async {
        buttonSoundOn = val;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('buttonSoundOn', val);
      },
    );
    add(_buttonToggle);

    // Game music toggle
    const gameToggleY = 178.0;
    add(
      TextComponent(
        text: 'Music',
        anchor: Anchor.centerLeft,
        position: Vector2(panelX + 16, gameToggleY),
        textRenderer: TextPaint(
          style: TextStyle(color: theme.contrastColor, fontSize: 18),
        ),
      ),
    );

    _gameToggle = _ProceduralToggleButton(
      position: Vector2(panelX + panelW - 30, gameToggleY),
      initialOn: gameSoundOn,
      onChanged: (val) async {
        gameSoundOn = val;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('gameSoundOn', val);
        if (!val) {
          try {
            await FlameAudio.bgm.stop();
          } catch (_) {}
        }
      },
    );
    add(_gameToggle);

    // --- SECTION: THEME ---
    const themeSectionY = 230.0;
    add(
      TextComponent(
        text: 'THEME',
        anchor: Anchor.topLeft,
        position: Vector2(panelX + 16, themeSectionY),
        textRenderer: TextPaint(
          style: TextStyle(
            color: OverlayBorder.gold,
            fontSize: 16,
            fontWeight: FontWeight.bold,
            letterSpacing: 2,
          ),
        ),
      ),
    );

    // Theme grid
    const gridStartY = 268.0;
    const gridGap = 8.0;
    const rowHeight = 44.0;
    const cols = 2;
    final colWidth = (panelW - 24 - gridGap * (cols - 1)) / cols;

    for (var i = 0; i < GameThemes.all.length; i++) {
      final t = GameThemes.all[i];
      final col = i % cols;
      final row = i ~/ cols;
      final gx = panelX + 16 + col * (colWidth + gridGap);
      final gy = gridStartY + row * (rowHeight + gridGap);
      add(
        _SettingsGridButton(
          label: t.name,
          position: Vector2(gx, gy),
          size: Vector2(colWidth, rowHeight),
          theme: t,
          onPressed: () async {
            await ThemeStore.save(t.id);
          },
        ),
      );
    }

    // --- BACK button below the theme grid ---
    add(
      ButtonComponent(
        label: 'BACK',
        theme: theme,
        position: Vector2(panelX + panelW / 2, panelY + panelH - 34),
        size: Vector2(140, 48),
        onPressed: () {
          game.router.pushNamed(returnRoute, replace: true);
        },
      ),
    );
  }
}

class _PanelBackground extends Component {
  final Rect rect;

  _PanelBackground({required this.rect});

  @override
  void render(Canvas canvas) {
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(16));
    final paint = Paint()
      ..shader = ui.Gradient.linear(rect.topLeft, rect.bottomLeft, [
        ThemeStore.current.buttonBase,
        ThemeStore.current.boardBackground,
      ]);
    canvas.drawRRect(rrect, paint);
    final borderPaint = Paint()
      ..color = ThemeStore.current.gridColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawRRect(rrect, borderPaint);
    final glow = Paint()
      ..color = ThemeStore.current.buttonHighlight.withValues(alpha: 0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawRRect(rrect, glow);
  }
}

/// A procedural toggle switch drawn entirely with Canvas - no PNG assets.
class _ProceduralToggleButton extends PositionComponent with TapCallbacks {
  bool _on;
  final Future<void> Function(bool) onChanged;

  _ProceduralToggleButton({
    required Vector2 position,
    required bool initialOn,
    required this.onChanged,
  }) : _on = initialOn,
       super(position: position, size: Vector2(56, 28), anchor: Anchor.center);

  @override
  void render(Canvas canvas) {
    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.x, size.y),
      const Radius.circular(14),
    );

    // Track background
    final trackPaint = Paint()
      ..color = _on
          ? const Color(0xFF4CAF50).withValues(alpha: 0.85)
          : const Color(0xFF555555).withValues(alpha: 0.6);
    canvas.drawRRect(rrect, trackPaint);

    // Track border
    final borderPaint = Paint()
      ..color = OverlayBorder.gold.withValues(alpha: 0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawRRect(rrect, borderPaint);

    // Thumb indicator (the circle that slides)
    final thumbRadius = size.y / 2 - 3;
    final thumbX =
        (_on ? 1.0 : 0.0) * (size.x - thumbRadius * 2 - 2) + thumbRadius + 1;
    final thumbPaint = Paint()
      ..color = _on ? const Color(0xFFFFFFFF) : const Color(0xFFCCCCCC)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(thumbX, size.y / 2), thumbRadius, thumbPaint);

    // Thumb subtle border
    final thumbBorder = Paint()
      ..color = OverlayBorder.gold.withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawCircle(Offset(thumbX, size.y / 2), thumbRadius, thumbBorder);
  }

  @override
  void onTapDown(TapDownEvent event) {
    if (SettingsScreen.buttonSoundOn) FlameAudio.play('button.wav');
    _on = !_on;
    onChanged(_on);
  }
}

class _SettingsGridButton extends PositionComponent with TapCallbacks {
  final String label;
  final GameTheme theme;
  final VoidCallback onPressed;

  late final TextComponent _labelComponent;
  _SettingsGridButton({
    required this.label,
    required Vector2 position,
    required Vector2 size,
    required this.theme,
    required this.onPressed,
  }) : super(position: position, size: size);

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    _labelComponent = TextComponent(
      text: label,
      position: Vector2(44, size.y / 2),
      anchor: Anchor.centerLeft,
      textRenderer: TextPaint(
        style: TextStyle(
          color: theme.textColor,
          fontSize: size.y * 0.4,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
    add(_labelComponent);
  }

  @override
  void render(Canvas canvas) {
    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.x, size.y),
      const Radius.circular(10),
    );
    final fillPaint = Paint()
      ..shader = ui.Gradient.linear(Offset(0, 0), Offset(0, size.y), [
        theme.buttonBase,
        theme.buttonHighlight,
      ]);
    canvas.drawRRect(rrect, fillPaint);
    final borderPaint = Paint()
      ..color = theme.gridColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawRRect(rrect, borderPaint);
    super.render(canvas);
  }

  @override
  void onTapDown(TapDownEvent event) {
    if (SettingsScreen.buttonSoundOn) FlameAudio.play('button.wav');
    add(
      SequenceEffect([
        ScaleEffect.to(Vector2(0.9, 0.9), EffectController(duration: 0.05)),
        ScaleEffect.to(Vector2(1.05, 1.05), EffectController(duration: 0.08)),
        ScaleEffect.to(Vector2.all(1), EffectController(duration: 0.05)),
      ]),
    );
    Future.delayed(const Duration(milliseconds: 150), onPressed);
  }
}
