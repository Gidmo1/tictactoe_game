import 'dart:async';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/effects.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart' hide Route;
import 'package:flame_audio/flame_audio.dart';
import 'package:tictactoe_game/privacy_options_screen.dart';
import 'package:tictactoe_game/settings_screen.dart';
import 'package:tictactoe_game/vs_ai_board.dart';
import 'firebase.dart';
import 'board.dart';
import 'competition_screen.dart';
import 'play_screen.dart';
import 'auth_gate.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class TicTacToeGame extends FlameGame
    with HasKeyboardHandlerComponents, TapCallbacks {
  late final RouterComponent router;
  String lastMessage = '';
  String loggedInUser = '';

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    await Firebaseinit().initFirebase();

    router = RouterComponent(
      initialRoute: 'menu',
      routes: {
        'menu': Route(() => MainMenuScreen()),
        'tictactoe': Route(() => TicTacToeBoard()),
        'settings': Route(() => SettingsScreen()),
        'vsai': Route(() => TicTacToeVsAI()),
        'competition': Route(() => CompetitionScreen()),
        'privacy': Route(() => PrivacyOptionsScreen()),
        'play_screen': Route(() => PlayScreen()),
      },
    );
    add(router);
  }
}

// Menu screen
class MainMenuScreen extends Component with HasGameReference<TicTacToeGame> {
  @override
  Future<void> onLoad() async {
    await super.onLoad();

    FlameAudio.bgm.play('background_music.mp3');

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

    // X
    final xSprite = await game.loadSprite('X.png');
    add(
      SpriteComponent(
        sprite: xSprite,
        size: Vector2(50, 50),
        position: Vector2(150, 150),
        anchor: Anchor.center,
      ),
    );

    // O
    final oSprite = await game.loadSprite('O.png');
    add(
      SpriteComponent(
        sprite: oSprite,
        size: Vector2(50, 50),
        position: Vector2(240, 150),
        anchor: Anchor.center,
      ),
    );

    // 🔥 Scores section
    final scores = await _getUserScores();
    add(
      TextComponent(
        text:
            "Wins: ${scores['wins']}  |  Losses: ${scores['losses']}  |  Draws: ${scores['draws']}",
        position: Vector2(game.size.x / 2, 250),
        anchor: Anchor.center,
        textRenderer: TextPaint(
          style: const TextStyle(
            fontSize: 20,
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );

    // Buttons
    final playSprite = await game.loadSprite('play.png');
    add(
      _ArcadeButton(
        sprite: playSprite,
        position: game.size / 2 + Vector2(0, -70),
        onPressed: () => game.router.pushNamed('tictactoe'),
      ),
    );

    final vsfriendSprite = await game.loadSprite('vsfriend.png');
    add(
      _ArcadeButton(
        sprite: vsfriendSprite,
        position: game.size / 2 + Vector2(0, 0),
        onPressed: () => game.router.pushNamed('tictactoe'),
      ),
    );

    final vscomputerSprite = await game.loadSprite('vscomputer.png');
    add(
      _ArcadeButton(
        sprite: vscomputerSprite,
        position: game.size / 2 + Vector2(0, 70),
        onPressed: () => game.router.pushNamed('vsai'),
      ),
    );

    // Helper function to check Facebook sign-in
    Future<bool> _isFacebookSignedIn() async {
      try {
        final user = FirebaseAuth.instance.currentUser;
        return user != null;
      } catch (_) {
        return false;
      }
    }

    final competitionSprite = await game.loadSprite('competition.png');
    add(
      _ArcadeButton(
        sprite: competitionSprite,
        position: game.size / 2 + Vector2(0, 140),
        onPressed: () async {
          final isSignedIn = await _isFacebookSignedIn();
          if (isSignedIn) {
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

  Future<Map<String, int>> _getUserScores() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return {"wins": 0, "losses": 0, "draws": 0};

    final snapshot = await FirebaseFirestore.instance
        .collection('scores')
        .where('playerId', isEqualTo: user.uid)
        .get();

    int wins = 0, losses = 0, draws = 0;

    for (var doc in snapshot.docs) {
      final data = doc.data();
      switch (data['result']) {
        case 'win':
          wins++;
          break;
        case 'loss':
          losses++;
          break;
        case 'draw':
          draws++;
          break;
      }
    }

    return {"wins": wins, "losses": losses, "draws": draws};
  }
}

class _ArcadeButton extends SpriteComponent with TapCallbacks {
  final VoidCallback onPressed;

  _ArcadeButton({
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
    if (SettingsScreen.buttonSoundOn) FlameAudio.play('tap.wav');

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
