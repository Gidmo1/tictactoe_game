import 'dart:async';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/effects.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart' hide Route;
import 'package:flame_audio/flame_audio.dart';
import 'package:tictactoe_game/privacy_options_screen.dart';
import 'package:tictactoe_game/profile_screen.dart';
import 'package:tictactoe_game/settings_screen.dart';
import 'package:tictactoe_game/vs_ai_board.dart';
import 'firebase.dart';
import 'board.dart';
import 'competition_screen.dart';
import 'auth_gate.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'models/user.dart' as app_user;

class TicTacToeGame extends FlameGame
    with HasKeyboardHandlerComponents, TapCallbacks {
  late final RouterComponent router;
  String lastMessage = '';
  String loggedInUser = '';

  //Selection state for difficulty screen
  String selectedDifficulty = 'medium';
  int? selectedRounds = 5;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    await Firebaseinit().initFirebase();

    router = RouterComponent(
      initialRoute: 'menu',
      routes: {
        'menu': Route(() => MainMenuScreen()),
        'profile': Route(() => ProfileScreen()),
        'tictactoe': Route(() => TicTacToeBoard()),
        'settings': Route(() => SettingsScreen()),
        'vsai': Route(() {
          final fbUser = FirebaseAuth.instance.currentUser;

          if (fbUser == null) {
            // Not logged in — still allow offline play
            return TicTacToeVsAI();
          }

          // Logged in — pass user info into the game
          final user = app_user.User(
            id: fbUser.uid,
            userName: fbUser.displayName ?? "Anonymous",
            providerId: fbUser.providerData.isNotEmpty
                ? fbUser.providerData[0].providerId
                : "firebase",
            providerName: fbUser.providerData.isNotEmpty
                ? fbUser.providerData[0].providerId
                : "firebase",
          );

          return TicTacToeVsAI(loggedInUser: user);
        }),

        'competition': Route(() => CompetitionScreen()),
        'privacy': Route(() => PrivacyOptionsScreen()),
      },
    );
    add(router);
  }
}

class MainMenuScreen extends Component with HasGameReference<TicTacToeGame> {
  TextComponent? scoreDisplay;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? scoreListener;

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    void playBackgroundMusic() {
      if (SettingsScreen.buttonSoundOn) {
        FlameAudio.bgm.play('background_music.mp3');
      } else {
        FlameAudio.bgm.stop();
      }
    }

    playBackgroundMusic();

    final background = SpriteComponent()
      ..sprite = await game.loadSprite('background.png')
      ..size = game.size
      ..position = Vector2.zero()
      ..priority = 0;
    add(background);

    add(
      TextComponent(
        text: '& ',
        position: Vector2(200, 150),
        anchor: Anchor.center,
        textRenderer: TextPaint(
          style: const TextStyle(
            fontSize: 40,
            color: Color.fromARGB(255, 255, 255, 255),
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );

    // X and O sprites
    final xSprite = await game.loadSprite('X.png');
    add(
      SpriteComponent(
        sprite: xSprite,
        size: Vector2(50, 50),
        position: Vector2(150, 150),
        anchor: Anchor.center,
      ),
    );

    final oSprite = await game.loadSprite('O.png');
    add(
      SpriteComponent(
        sprite: oSprite,
        size: Vector2(50, 50),
        position: Vector2(240, 150),
        anchor: Anchor.center,
      ),
    );

    final profileSprite = await game.loadSprite('profile.png');

    add(
      ProfileAvatar(
        sprite: profileSprite,
        size: Vector2(60, 60),
        position: Vector2(50, 60),
        onTap: () {
          game.router.pushNamed('profile');
        },
      ),
    );

    // Buttons
    final playSprite = await game.loadSprite('play.png');
    add(
      _PressdownButton(
        sprite: playSprite,
        position: game.size / 2 + Vector2(0, -70),
        onPressed: () => game.router.pushNamed('tictactoe'),
      ),
    );

    final vsfriendSprite = await game.loadSprite('vsfriend.png');
    add(
      _PressdownButton(
        sprite: vsfriendSprite,
        position: game.size / 2,
        onPressed: () => game.router.pushNamed('tictactoe'),
      ),
    );

    final vscomputerSprite = await game.loadSprite('vscomputer.png');
    add(
      _PressdownButton(
        sprite: vscomputerSprite,
        position: game.size / 2 + Vector2(0, 70),
        onPressed: () {
          final g = game as TicTacToeGame;
          g.router.pushNamed('vsai');
        },
      ),
    );

    final competitionSprite = await game.loadSprite('competition.png');
    add(
      _PressdownButton(
        sprite: competitionSprite,
        position: game.size / 2 + Vector2(0, 140),
        onPressed: () async {
          final user = FirebaseAuth.instance.currentUser;
          if (user != null) {
            game.router.pushNamed('competition');
          } else {
            showDialog(
              context: game.buildContext!,
              builder: (context) =>
                  SizedBox(width: 400, height: 400, child: const AuthGate()),
              barrierDismissible: false,
            );
          }
        },
      ),
    );
  }
}

class ProfileAvatar extends SpriteComponent with TapCallbacks {
  final VoidCallback onTap;

  ProfileAvatar({
    required Sprite sprite,
    required Vector2 position,
    required Vector2 size,
    required this.onTap,
  }) : super(
         sprite: sprite,
         position: position,
         size: size,
         anchor: Anchor.center,
       );

  @override
  void onTapDown(TapDownEvent event) {
    if (SettingsScreen.buttonSoundOn) FlameAudio.play('button.wav');
    onTap();
  }
}

class _PressdownButton extends SpriteComponent with TapCallbacks {
  final VoidCallback onPressed;

  _PressdownButton({
    required Sprite sprite,
    required Vector2 position,
    required this.onPressed,
    Vector2? size,
  }) : super(
         sprite: sprite,
         size: size ?? Vector2(200, 60),
         position: position,
         anchor: Anchor.center,
       );

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

    Future.delayed(const Duration(milliseconds: 150), () {
      onPressed();
    });
  }
}
