import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flutter/material.dart';

import '../components/button.dart';
import 'theme.dart';
import 'theme_store.dart';

/// Simple theme switcher — the seed of the Identity Shop.
///
/// Lists every [GameTheme], previews its X/O symbols live, and persists the
/// selection via [ThemeStore]. Boards/menus read [ThemeStore.load] on load, so
/// the new skin appears once you navigate back.
class ThemePickerScreen extends Component {
  GameTheme current = GameThemes.classic;
  TextComponent? _status;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    final canvas = findGame()?.size ?? Vector2(360, 640);
    current = ThemeStore.current;

    final background = RectangleComponent(
      size: canvas,
      paint: Paint()..color = current.boardBackground,
    );
    add(background);

    add(
      TextComponent(
        text: 'THEMES',
        position: Vector2(canvas.x / 2, 60),
        anchor: Anchor.center,
        textRenderer: TextPaint(
          style: TextStyle(
            fontSize: 26,
            color: current.contrastColor,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );

    _status = TextComponent(
      text: current.name,
      position: Vector2(canvas.x / 2, 92),
      anchor: Anchor.center,
      textRenderer: TextPaint(
        style: TextStyle(fontSize: 16, color: current.gridColor),
      ),
    );
    add(_status!);

    const rowHeight = 84.0;
    const gap = 14.0;
    final themes = GameThemes.all;
    final startY = 160.0 + (themes.length > 4 ? (themes.length - 4) * 0 : 0);
    for (var i = 0; i < themes.length; i++) {
      final t = themes[i];
      add(
        _ThemeOption(
          theme: t,
          size: Vector2(canvas.x * 0.9, rowHeight),
          position: Vector2(canvas.x / 2, startY + i * (rowHeight + gap)),
          onTap: () => _select(t),
        ),
      );
    }

    add(
      ButtonComponent(
        label: 'BACK',
        theme: current,
        position: Vector2(canvas.x / 2, canvas.y - 50),
        size: Vector2(150, 48),
        onPressed: () {
          final game = findGame();
          (game as dynamic).router?.pushReplacementNamed('menu');
        },
      ),
    );
  }

  void _select(GameTheme t) async {
    await ThemeStore.save(t.id);
    current = ThemeStore.current;
    current = t;
    _status?.text = '${t.name} — applied';
    final game = findGame();
    (game as dynamic).router?.pushReplacementNamed('themes');
  }
}

class _ThemeOption extends PositionComponent with TapCallbacks {
  final GameTheme theme;
  final void Function() onTap;

  _ThemeOption({
    required this.theme,
    required Vector2 size,
    required Vector2 position,
    required this.onTap,
  }) : super(size: size, position: position, anchor: Anchor.center);

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    final chip = RectangleComponent(
      size: size,
      paint: Paint()..color = theme.boardBackground,
    );
    add(chip);

    final border = RectangleComponent(
      size: size,
      paint: Paint()
        ..color = theme.gridColor.withValues(alpha: 0.4)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    add(border);

    // Live X/O preview
    final sym = size.y * 0.55;
    add(
      SpriteComponent(
        sprite: await theme.symbolSprite('X', sym, pixelRatio: 4),
        size: Vector2(sym, sym),
        position: Vector2(size.y * 0.9, size.y / 2),
        anchor: Anchor.center,
      ),
    );
    add(
      SpriteComponent(
        sprite: await theme.symbolSprite('O', sym, pixelRatio: 4),
        size: Vector2(sym, sym),
        position: Vector2(size.y * 1.7, size.y / 2),
        anchor: Anchor.center,
      ),
    );

    add(
      TextComponent(
        text: theme.name,
        position: Vector2(size.x / 2 + size.y * 0.4, size.y / 2),
        anchor: Anchor.center,
        textRenderer: TextPaint(
          style: TextStyle(
            fontSize: 20,
            color: theme.contrastColor,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  @override
  void onTapDown(TapDownEvent event) => onTap();
}
