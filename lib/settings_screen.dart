import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flame/events.dart';
import 'package:flame_audio/flame_audio.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tictactoe_game/tictactoe.dart';

class SettingsScreen extends Component
    with HasGameReference<TicTacToeGame>, TapCallbacks {
  static bool buttonSoundOn = true;
  static bool gameSoundOn = true;
  String? playerId;

  // Sprites
  late Sprite toggleRightSprite;
  late Sprite toggleLeftSprite;
  late Sprite toggleRightBgSprite;
  late Sprite toggleLeftBgSprite;

  // Components
  late SpriteComponent toggleBg;
  late _SoundToggleButton toggleButton;

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    // Load sprites
    toggleRightSprite = await game.loadSprite('toggle_right.png');
    toggleLeftSprite = await game.loadSprite('toggle_left.png');
    toggleRightBgSprite = await game.loadSprite('toggle_rightb.png');
    toggleLeftBgSprite = await game.loadSprite('toggle_leftb.png');

    // Background
    final bgSprite = await game.loadSprite('background.png');
    add(
      SpriteComponent(
        sprite: bgSprite,
        size: game.size,
        position: Vector2.zero(),
      ),
    );

    // Settings panel
    final panelSprite = await game.loadSprite('settings_page.png');
    add(
      SpriteComponent(
        sprite: panelSprite,
        size: Vector2(370, 410),
        position: Vector2(6, 120),
      ),
    );

    // Toggle BG
    toggleBg = SpriteComponent(
      size: Vector2(60, 30),
      position: Vector2(305, 175),
      anchor: Anchor.center,
    );
    add(toggleBg);

    // Toggle button
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

        if (gameSoundOn) {
          if (!FlameAudio.bgm.isPlaying)
            FlameAudio.bgm.play('background_music.mp3');
        } else {
          FlameAudio.bgm.stop();
        }
      },
    );
    add(toggleButton);

    // Buttons
    final returnSprite = await game.loadSprite('return.png');
    add(
      _ReturnButton(
        sprite: returnSprite,
        position: Vector2(10, 50),
        onPressed: () => game.router.pushReplacementNamed('tictactoe'),
      ),
    );

    final resetSprite = await game.loadSprite('reset.png');
    add(
      _ResetSprite(
        sprite: resetSprite,
        position: Vector2(210, 200),
        onPressed: () {},
      ),
    );

    final adsSprite = await game.loadSprite('remove_ads.png');
    add(
      _AdsSprite(
        sprite: adsSprite,
        position: Vector2(210, 250),
        onPressed: () {},
      ),
    );

    final privacySprite = await game.loadSprite('privacy_edit.png');
    add(
      _PrivacySprite(
        sprite: privacySprite,
        position: Vector2(210, 300),
        onPressed: () => game.router.pushNamed('privacy'),
      ),
    );

    // Load saved state & sync visuals
    await _loadSoundState();
  }

  Future<void> _loadSoundState() async {
    final prefs = await SharedPreferences.getInstance();
    buttonSoundOn = prefs.getBool('buttonSoundOn') ?? true;
    gameSoundOn = prefs.getBool('gameSoundOn') ?? true;

    // Update toggle position and sprite immediately
    toggleBg.sprite = buttonSoundOn ? toggleRightBgSprite : toggleLeftBgSprite;
    toggleButton.soundOn = buttonSoundOn;
    double bgMin = toggleButton.minX + toggleButton.radius;
    double bgMax = toggleButton.maxX - toggleButton.radius;
    toggleButton.position.x = buttonSoundOn ? bgMax : bgMin;
    toggleButton.sprite = buttonSoundOn
        ? toggleButton.rightSprite
        : toggleButton.leftSprite;

    // Firestore sync in background
    final user = FirebaseAuth.instance.currentUser;
    playerId = user?.uid;
    if (playerId != null) {
      FirebaseFunctions.instanceFor(region: 'us-central1')
          .httpsCallable('getUserSettings')
          .call({'playerId': playerId})
          .then((result) async {
            final data = result.data as Map<String, dynamic>? ?? {};
            final cloudButton = data['buttonSoundOn'] ?? buttonSoundOn;
            final cloudGame = data['gameSoundOn'] ?? gameSoundOn;
            await prefs.setBool('buttonSoundOn', cloudButton);
            await prefs.setBool('gameSoundOn', cloudGame);
          })
          .catchError((e) => print('Cloud load failed: $e'));
    }
  }

  Future<void> _saveSoundState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('buttonSoundOn', buttonSoundOn);
    await prefs.setBool('gameSoundOn', gameSoundOn);

    if (playerId != null) {
      FirebaseFunctions.instanceFor(region: 'us-central1')
          .httpsCallable('updateUserSettings')
          .call({
            'playerId': playerId,
            'buttonSoundOn': buttonSoundOn,
            'gameSoundOn': gameSoundOn,
          })
          .catchError((e) => print('Cloud save failed: $e'));
    }
  }
}

// Toggle Button
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

// Remaining buttons
class _ResetSprite extends SpriteComponent with TapCallbacks {
  final VoidCallback onPressed;
  _ResetSprite({
    required Sprite sprite,
    required Vector2 position,
    required this.onPressed,
  }) : super(sprite: sprite, size: Vector2(130, 40), position: position);

  @override
  void onTapDown(TapDownEvent event) {
    if (SettingsScreen.buttonSoundOn) FlameAudio.play('button.wav');
    onPressed();
  }
}

class _PrivacySprite extends SpriteComponent with TapCallbacks {
  final VoidCallback onPressed;
  _PrivacySprite({
    required Sprite sprite,
    required Vector2 position,
    required this.onPressed,
  }) : super(sprite: sprite, size: Vector2(130, 40), position: position);

  @override
  void onTapDown(TapDownEvent event) {
    if (SettingsScreen.buttonSoundOn) FlameAudio.play('button.wav');
    add(
      SequenceEffect([
        ScaleEffect.to(Vector2(0.9, 0.9), EffectController(duration: 0.05)),
        ScaleEffect.to(
          Vector2(1.05, 1.05),
          EffectController(duration: 0.08, curve: Curves.easeOut),
        ),
        ScaleEffect.to(
          Vector2(1.0, 1.0),
          EffectController(duration: 0.05, curve: Curves.easeIn),
        ),
      ]),
    );
    Future.delayed(const Duration(milliseconds: 150), () => onPressed());
  }
}

class _AdsSprite extends SpriteComponent with TapCallbacks {
  final VoidCallback onPressed;
  _AdsSprite({
    required Sprite sprite,
    required Vector2 position,
    required this.onPressed,
  }) : super(sprite: sprite, size: Vector2(130, 40), position: position);

  @override
  void onTapDown(TapDownEvent event) {
    if (SettingsScreen.buttonSoundOn) FlameAudio.play('button.wav');
    onPressed();
  }
}

class _ReturnButton extends SpriteComponent with TapCallbacks {
  final VoidCallback onPressed;
  _ReturnButton({
    required Sprite sprite,
    required Vector2 position,
    required this.onPressed,
  }) : super(sprite: sprite, size: Vector2(50, 50), position: position);

  @override
  void onTapDown(TapDownEvent event) {
    if (SettingsScreen.buttonSoundOn) FlameAudio.play('button.wav');
    onPressed();
  }
}
