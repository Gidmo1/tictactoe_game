import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flame/events.dart';
import 'package:flame_audio/flame_audio.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tictactoe_game/components/button.dart';
import 'package:tictactoe_game/game_themes/theme.dart';
import 'package:tictactoe_game/game_themes/theme_store.dart';
import 'package:tictactoe_game/tictactoe.dart';

class SettingsScreen extends Component
    with HasGameReference<TicTacToeGame>, TapCallbacks {
  static bool buttonSoundOn = true;
  static bool gameSoundOn = true;

  late Sprite toggleRightSprite;
  late Sprite toggleLeftSprite;
  late Sprite toggleRightBgSprite;
  late Sprite toggleLeftBgSprite;

  late SpriteComponent toggleBg;
  late _SoundToggleButton toggleButton;
  GameTheme get theme => ThemeStore.current;

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    toggleRightSprite = await game.loadSprite('toggle_right.png');
    toggleLeftSprite = await game.loadSprite('toggle_left.png');
    toggleRightBgSprite = await game.loadSprite('toggle_rightb.png');
    toggleLeftBgSprite = await game.loadSprite('toggle_leftb.png');

    add(
      RectangleComponent(
        size: game.size,
        position: Vector2.zero(),
        paint: Paint()..color = theme.boardBackground,
      ),
    );

    add(
      RectangleComponent(
        size: Vector2(370, 410),
        position: Vector2(6, 120),
        paint: Paint()..color = theme.contrastColor.withValues(alpha: 0.2),
      ),
    );

    add(
      TextComponent(
        text: 'SETTINGS',
        anchor: Anchor.topCenter,
        position: Vector2(game.size.x / 2, 20),
        textRenderer: TextPaint(
          style: TextStyle(
            color: theme.contrastColor,
            fontSize: 28,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
    add(
      TextComponent(
        text: 'Sound',
        anchor: Anchor.centerLeft,
        position: Vector2(30, 175),
        textRenderer: TextPaint(
          style: TextStyle(
            color: theme.contrastColor,
            fontSize: 18,
          ),
        ),
      ),
    );

    toggleBg = SpriteComponent(
      size: Vector2(60, 30),
      position: Vector2(305, 175),
      anchor: Anchor.center,
    );
    add(toggleBg);

    toggleButton = _SoundToggleButton(
      leftSprite: toggleLeftSprite,
      rightSprite: toggleRightSprite,
      leftBg: toggleLeftBgSprite,
      rightBg: toggleRightBgSprite,
      position: Vector2(280, 174),
      size: Vector2(28, 28),
      minX: 274,
      maxX: 335,
      soundOn: buttonSoundOn,
      onChanged: (on) async {
        buttonSoundOn = on;
        gameSoundOn = on;
        toggleBg.sprite = on ? toggleRightBgSprite : toggleLeftBgSprite;

        await _saveSoundState();
        try {
          final g = game;
          if (gameSoundOn) {
            g.playMenuMusic();
          } else {
            g.stopMenuMusic();
          }
        } catch (_) {}
      },
    );
    add(toggleButton);

    add(
      ButtonComponent(
        label: 'BACK',
        position: Vector2(10, 50),
        size: Vector2(80, 40),
        theme: theme,
        onPressed: () => game.router.pushReplacementNamed('menu'),
      ),
    );

    add(
      ButtonComponent(
        label: 'RESET',
        position: Vector2(210, 200),
        size: Vector2(130, 40),
        theme: theme,
        onPressed: () {},
      ),
    );

    add(
      ButtonComponent(
        label: 'REMOVE ADS',
        position: Vector2(210, 250),
        size: Vector2(130, 40),
        theme: theme,
        onPressed: () {},
      ),
    );

    add(
      ButtonComponent(
        label: 'PRIVACY',
        position: Vector2(210, 300),
        size: Vector2(130, 40),
        theme: theme,
        onPressed: () => game.router.pushNamed('privacy'),
      ),
    );

    await _loadSoundState();
  }
  Future<void> _loadSoundState() async {
    final prefs = await SharedPreferences.getInstance();
    buttonSoundOn = prefs.getBool('buttonSoundOn') ?? true;
    gameSoundOn = prefs.getBool('gameSoundOn') ?? true;

    toggleBg.sprite = buttonSoundOn ? toggleRightBgSprite : toggleLeftBgSprite;
    toggleButton.soundOn = buttonSoundOn;
    double bgMin = toggleButton.minX + toggleButton.radius;
    double bgMax = toggleButton.maxX - toggleButton.radius;
    toggleButton.position.x = buttonSoundOn ? bgMax : bgMin;
    toggleButton.sprite =
        buttonSoundOn ? toggleButton.rightSprite : toggleButton.leftSprite;
  }

  Future<void> _saveSoundState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('buttonSoundOn', buttonSoundOn);
    await prefs.setBool('gameSoundOn', gameSoundOn);
  }
}

class _SoundToggleButton extends SpriteComponent with TapCallbacks {
  final double minX;
  final double maxX;
  bool soundOn;
  final Future<void> Function(bool) onChanged;
  final Sprite leftSprite;
  final Sprite rightSprite;
  final Sprite leftBg;
  final Sprite rightBg;

  _SoundToggleButton({
    required this.leftSprite,
    required this.rightSprite,
    required this.leftBg,
    required this.rightBg,
    required Vector2 position,
    required Vector2 size,
    required this.minX,
    required this.maxX,
    required this.soundOn,
    required this.onChanged,
  }) : super(
          position: position,
          size: size,
          anchor: Anchor.center,
          sprite: soundOn ? rightSprite : leftSprite,
        );

  double get radius => size.x / 2;

  @override
  Future<void> onLoad() async {
    double bgMin = minX + radius;
    double bgMax = maxX - radius;
    position.x = soundOn ? bgMax : bgMin;
    sprite = soundOn ? rightSprite : leftSprite;
  }

  @override
  void onTapDown(TapDownEvent event) async {
    if (SettingsScreen.buttonSoundOn) FlameAudio.play('button.wav');

    soundOn = !soundOn;
    double bgMin = minX + radius;
    double bgMax = maxX - radius;
    double targetX = soundOn ? bgMax : bgMin;

    add(
      MoveEffect.to(
        Vector2(targetX, position.y),
        EffectController(duration: 0.2, curve: Curves.easeOut),
      ),
    );

    sprite = soundOn ? rightSprite : leftSprite;
    await onChanged(soundOn);
  }
}
