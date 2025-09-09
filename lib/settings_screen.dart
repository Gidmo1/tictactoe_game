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

    // Load sound state from Firestore in background (don't block UI)
    _loadSoundState();

    // Ultimate background
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
        size: Vector2(250, 100),
        position: Vector2(80, 100),
      ),
    );

    // Load toggle backgrounds
    final toggleLeftBgSprite = await game.loadSprite('toggle_leftb.png');
    final toggleRightBgSprite = await game.loadSprite('toggle_rightb.png');
    // Load toggle buttons
    final toggleLeftSprite = await game.loadSprite('toggle_left.png');
    final toggleRightSprite = await game.loadSprite('toggle_right.png');

    // Add left toggle background and button (button sound, minimized)
    add(
      SpriteComponent(
        sprite: toggleLeftBgSprite,
        size: Vector2(38, 22),
        position: Vector2(285, 125),
        anchor: Anchor.center,
      ),
    );
    add(
      _SoundToggleButton(
        sprite: toggleLeftSprite,
        position: Vector2(285, 125),
        size: Vector2(16, 16),
        minX: 269, // allow to reach left edge
        maxX: 301, // allow to reach right edge
        soundOn: buttonSoundOn,
        onChanged: (on) async {
          buttonSoundOn = on;
          await _saveSoundState();
        },
      ),
    );
    // Add right toggle background and button (game sound, minimized)
    add(
      SpriteComponent(
        sprite: toggleRightBgSprite,
        size: Vector2(38, 22),
        position: Vector2(285, 170),
        anchor: Anchor.center,
      ),
    );
    add(
      _SoundToggleButton(
        sprite: toggleRightSprite,
        position: Vector2(285, 170),
        size: Vector2(16, 16),
        minX: 269, // allow to reach left edge
        maxX: 301, // allow to reach right edge
        soundOn: gameSoundOn,
        onChanged: (on) async {
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

    // Add sign-in button further down
    /* final loginSprite = await game.loadSprite('login_button.png');
    add(
      _FacebookLoginButton(
        sprite: loginSprite,
        position: Vector2(200, 250),
        settingsScreen: this,
      ),
    );

    // Add logout button
    final logoutSprite = await game.loadSprite('logout.png');
    add(
      _LogoutButton(
        sprite: logoutSprite,
        position: Vector2(200, 320),
        settingsScreen: this,
      ),
    );*/
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
    // Clamp so the edge of the circle never exceeds the background
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

/*class _FacebookLoginButton extends SpriteComponent with TapCallbacks {
  final SettingsScreen settingsScreen;
  _FacebookLoginButton({
    required Sprite sprite,
    required Vector2 position,
    required this.settingsScreen,
    Vector2? size,
  }) : super(
         sprite: sprite,
         size: size ?? Vector2(200, 60),
         position: position,
         anchor: Anchor.center,
       );

  @override
  void onTapDown(TapDownEvent event) async {
    if (SettingsScreen.buttonSoundOn) FlameAudio.play('tap.wav');
    try {
      await FacebookAuth.instance.logOut(); // Force account picker
      final result = await FacebookAuth.instance.login(
        permissions: ['public_profile'],
        loginBehavior: LoginBehavior.webOnly,
      );
      if (result.status == LoginStatus.success && result.accessToken != null) {
        final accessToken = result.accessToken!.token;
        final facebookCredential = FacebookAuthProvider.credential(accessToken);
        final userCred = await FirebaseAuth.instance.signInWithCredential(
          facebookCredential,
        );
        settingsScreen.userId = userCred.user?.uid;
        settingsScreen.add(
          _ConfirmationOverlay(
            message:
                'Successfully signed in as ${userCred.user?.displayName ?? userCred.user?.email ?? 'Unknown'}',
          ),
        );
      }
    } catch (e) {
      // Optionally show error overlay here
    }
  }
}

class _LogoutButton extends SpriteComponent with TapCallbacks {
  final SettingsScreen settingsScreen;
  _LogoutButton({
    required Sprite sprite,
    required Vector2 position,
    required this.settingsScreen,
    Vector2? size,
  }) : super(
         sprite: sprite,
         size: size ?? Vector2(200, 60),
         position: position,
         anchor: Anchor.center,
       );

  @override
  void onTapDown(TapDownEvent event) async {
    if (SettingsScreen.buttonSoundOn) FlameAudio.play('tap.wav');
    await FirebaseAuth.instance.signOut();
    settingsScreen.add(
      _ConfirmationOverlay(message: 'Logged out successfully'),
    );
  }
}

class _ConfirmationOverlay extends PositionComponent {
  final String message;
  _ConfirmationOverlay({required this.message});

  @override
  Future<void> onLoad() async {
    size = Vector2(340, 60);
    position = Vector2(40, 400);
    priority = 1000;
    add(
      RectangleComponent(
        position: Vector2.zero(),
        size: size,
        paint: Paint()..color = const Color(0xCC000000),
        priority: 1001,
      ),
    );
    final tickSprite = await Sprite.load(
      'notifications.png',
    ); // Use your green tick asset if available
    add(
      SpriteComponent(
        sprite: tickSprite,
        size: Vector2(28, 28),
        position: Vector2(24, size.y / 2),
        anchor: Anchor.centerLeft,
        priority: 1002,
      ),
    );
    add(
      TextComponent(
        text: message,
        position: Vector2(64, size.y / 2),
        anchor: Anchor.centerLeft,
        textRenderer: TextPaint(
          style: const TextStyle(
            fontSize: 18,
            color: Color(0xFFFFFFFF),
            fontWeight: FontWeight.bold,
            shadows: [
              Shadow(
                color: Color(0xFF008000),
                blurRadius: 8,
                offset: Offset(0, 2),
              ),
            ],
          ),
        ),
        priority: 1003,
      ),
    );
    Future.delayed(const Duration(seconds: 5), () {
      removeFromParent();
    });
  }
}*/

// Update all FlameAudio.play calls in your game to check SettingsScreen.buttonSoundOn or gameSoundOn before playing
// Example:
// if (SettingsScreen.buttonSoundOn) FlameAudio.play('tap.wav');
// if (SettingsScreen.gameSoundOn) FlameAudio.play('win.wav');
// if (SettingsScreen.gameSoundOn) FlameAudio.play('lose.wav');
