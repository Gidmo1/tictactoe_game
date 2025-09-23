import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
//import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame_audio/flame_audio.dart';
import 'package:flutter/widgets.dart';
import 'package:tictactoe_game/tictactoe.dart';
import 'package:flame/effects.dart';

class SettingsScreen extends Component
    with HasGameReference<TicTacToeGame>, TapCallbacks {
  static bool buttonSoundOn = true;
  static bool gameSoundOn = true;
  String? userId;

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    // Load sound state from Firestore in background
    _loadSoundState();

    // Screen background
    final backgroundSprite = await game.loadSprite('background.png');
    add(
      SpriteComponent(
        sprite: backgroundSprite,
        size: game.size,
        position: Vector2.zero(),
      ),
    );

    // Settings page overlay
    final settingsPageSprite = await game.loadSprite('settings_page.png');
    add(
      SpriteComponent(
        sprite: settingsPageSprite,
        size: Vector2(370, 410),
        position: Vector2(6, 120),
      ),
    );

    // Load toggle background
    final toggleLeftBgSprite = await game.loadSprite('toggle_rightb.png');
    // Load toggle button
    final toggleLeftSprite = await game.loadSprite('toggle_right.png');

    // Add left toggle background and button
    add(
      SpriteComponent(
        sprite: toggleLeftBgSprite,
        size: Vector2(60, 30),
        position: Vector2(305, 175),
        anchor: Anchor.center,
      ),
    );
    add(
      _SoundToggleButton(
        sprite: toggleLeftSprite,
        position: Vector2(280, 174),
        size: Vector2(28, 28),
        minX: 274, // allow to reach left edge
        maxX: 335, // allow to reach right edge
        soundOn: buttonSoundOn,
        onChanged: (on) async {
          buttonSoundOn = on;
          await _saveSoundState();
          gameSoundOn = on;
          await _saveSoundState();
        },
      ),
    );

    final returnSprite = await game.loadSprite('return.png');
    add(
      _ReturnButton(
        sprite: returnSprite,
        position: Vector2(20, 50),
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
  }

  Future<void> _loadSoundState() async {
    final user = FirebaseAuth.instance.currentUser;
    userId = user?.uid;
    if (userId == null) return;
    final doc = await FirebaseFirestore.instance
        .collection('Users')
        .doc(userId)
        .get();
    if (doc.exists) {
      buttonSoundOn = doc.data()?['buttonSoundOn'] ?? true;
      gameSoundOn = doc.data()?['gameSoundOn'] ?? true;
    }
  }

  Future<void> _saveSoundState() async {
    if (userId == null) return;
    await FirebaseFirestore.instance.collection('Users').doc(userId).set({
      'buttonSoundOn': buttonSoundOn,
      'gameSoundOn': gameSoundOn,
    }, SetOptions(merge: true));
  }
}

class _ResetSprite extends SpriteComponent with TapCallbacks {
  final VoidCallback onPressed;
  _ResetSprite({
    required Sprite sprite,
    required Vector2 position,
    required this.onPressed,
  }) : super(sprite: sprite, size: Vector2(130, 40), position: position);

  @override
  void onTapDown(TapDownEvent event) {
    if (SettingsScreen.buttonSoundOn) FlameAudio.play('tap.wav');
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
    if (SettingsScreen.buttonSoundOn) FlameAudio.play('tap.wav');

    // Arcade bounce effect
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
    //To route after bounce
    Future.delayed(Duration(milliseconds: 150), () => onPressed());
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
    if (SettingsScreen.buttonSoundOn) FlameAudio.play('tap.wav');
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
    if (SettingsScreen.buttonSoundOn) FlameAudio.play('tap.wav');
    onPressed();
  }
}

class _SoundToggleButton extends SpriteComponent with TapCallbacks {
  final double minX;
  final double maxX;
  bool soundOn;
  final Future<void> Function(bool) onChanged;
  _SoundToggleButton({
    required Sprite sprite,
    required Vector2 position,
    required Vector2 size,
    required this.minX,
    required this.maxX,
    required this.soundOn,
    required this.onChanged,
  }) : super(
         sprite: sprite,
         position: position,
         size: size,
         anchor: Anchor.center,
       );

  double get radius => size.x / 2;

  @override
  Future<void> onLoad() async {
    // The circle not to exceed the background
    double bgMin = minX + radius;
    double bgMax = maxX - radius;
    position.x = soundOn ? bgMax : bgMin;
  }

  @override
  void onTapDown(TapDownEvent event) async {
    if (SettingsScreen.buttonSoundOn) FlameAudio.play('tap.wav');
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
    position.x = targetX;
    await onChanged(soundOn);
  }
}
