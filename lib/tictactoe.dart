import 'dart:async';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/effects.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart' hide Route;
import 'package:flame_audio/flame_audio.dart';
import 'package:tictactoe_game/settings_screen.dart';
import 'package:tictactoe_game/vs_ai_board.dart';
import 'firebase.dart';
import 'board.dart';
import 'competition_screen.dart';
import 'quick_match_screen.dart';
import 'global_leaderboard_screen.dart';
import 'play_screen.dart';
import 'auth_gate.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'league_leaderboard_screen.dart';

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
        'menu': Route(MainMenuScreen.new),
        'tictactoe': Route(TicTacToeBoard.new),
        'settings': Route(SettingsScreen.new),
        'vsai': Route(TicTacToeVsAI.new),
        // Removed: 'difficulty': Route(DifficultyScreen.new),
        'competition': Route(() => CompetitionScreen()),
        'quick_match': Route(() => QuickMatchScreen()),
        'global_leaderboard': Route(() => GlobalLeaderboardScreen()),
        'league_leaderboard': Route(() => LeagueLeaderboardScreen()),
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

    final background = SpriteComponent()
      ..sprite = await game.loadSprite('background.png')
      ..size = game.size
      ..position = Vector2.zero()
      ..priority = 0;
    add(background);

    // ...existing code...

    add(
      TextComponent(
        text: '& ',
        position: Vector2(200, 150),
        anchor: Anchor.center,
        textRenderer: TextPaint(
          style: const TextStyle(
            fontSize: 70,
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
        size: Vector2(100, 100),
        position: Vector2(120, 150),
        anchor: Anchor.center,
      ),
    );

    // O
    final oSprite = await game.loadSprite('O.png');
    add(
      SpriteComponent(
        sprite: oSprite,
        size: Vector2(100, 100),
        position: Vector2(280, 150),
        anchor: Anchor.center,
      ),
    );

    // Buttons with arcade-style bounce
    final playSprite = await game.loadSprite('play.png');
    add(
      _ArcadeButton(
        sprite: playSprite,
        position: game.size / 2 + Vector2(0, 50),
        onPressed: () => game.router.pushNamed('tictactoe'),
      ),
    );

    final vsfriendSprite = await game.loadSprite('vsfriend.png');
    add(
      _ArcadeButton(
        sprite: vsfriendSprite,
        position: game.size / 2 + Vector2(0, 120),
        onPressed: () => game.router.pushNamed('tictactoe'),
      ),
    );

    final vscomputerSprite = await game.loadSprite('vscomputer.png');
    add(
      _ArcadeButton(
        sprite: vscomputerSprite,
        position: game.size / 2 + Vector2(0, 190),
        onPressed: () => game.router.pushNamed('difficulty'),
      ),
    );

    // Helper function to check Facebook sign-in
    Future<bool> _isFacebookSignedIn() async {
      try {
        final user = await FirebaseAuth.instance.currentUser;
        return user != null;
      } catch (_) {
        return false;
      }
    }

    final competitionSprite = await game.loadSprite('competition.png');
    add(
      _ArcadeButton(
        sprite: competitionSprite,
        position: game.size / 2 + Vector2(0, 260),
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

    // Remove Facebook login button from tictactoe.dart
  }
}

// Arcade-style button
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

  void onTapDown(TapDownEvent event) {
    if (SettingsScreen.buttonSoundOn) FlameAudio.play('tap.wav');

    add(
      SequenceEffect([
        ScaleEffect.to(
          Vector2(0.9, 0.9),
          EffectController(duration: 0.05),
        ), // squash
        ScaleEffect.to(
          Vector2(1.05, 1.05),
          EffectController(duration: 0.08, curve: Curves.easeOut),
        ), // overshoot
        ScaleEffect.to(
          Vector2(1.0, 1.0),
          EffectController(duration: 0.05, curve: Curves.easeIn),
        ), // settle
      ]),
    );

    // Delay action to see effect
    Future.delayed(Duration(milliseconds: 150), () {
      onPressed();
    });
  }
}
