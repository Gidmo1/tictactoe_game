import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flame_audio/flame_audio.dart';
import 'package:flutter/material.dart' hide Route;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tictactoe_game/tictactoe.dart';
import 'settings_screen.dart';

class ProfileScreen extends Component with HasGameReference<TicTacToeGame> {
  late SpriteComponent background;
  late SpriteComponent panel;
  late SpriteComponent avatar;
  late TextComponent nameText;
  late TextComponent statsText;
  late _ReturnButton returnButton;

  String playerName = 'Anonymous';
  int wins = 0;
  int losses = 0;
  int draws = 0;

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    final bgSprite = await game.loadSprite('background.png');
    background = SpriteComponent(
      sprite: bgSprite,
      size: game.size,
      position: Vector2.zero(),
    );
    add(background);

    final panelSprite = await game.loadSprite('profile_background.png');
    panel = SpriteComponent(
      sprite: panelSprite,
      size: Vector2(370, 410),
      position: Vector2(6, 120),
    );
    add(panel);

    // Avatar
    final avatarSprite = await game.loadSprite('profile.png');
    avatar = SpriteComponent(
      sprite: avatarSprite,
      size: Vector2(100, 100),
      position: Vector2(game.size.x / 2 - 50, 140),
    );
    add(avatar);

    // Load cached + online user info
    await _loadPlayerData();

    // Player name and stats
    nameText = TextComponent(
      text: playerName,
      position: Vector2(game.size.x / 2, 250),
      anchor: Anchor.center,
      textRenderer: TextPaint(
        style: const TextStyle(
          fontSize: 20,
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
    add(nameText);

    statsText = TextComponent(
      text: 'W:$wins  L:$losses  D:$draws',
      position: Vector2(game.size.x / 2, 290),
      anchor: Anchor.center,
      textRenderer: TextPaint(
        style: const TextStyle(
          fontSize: 16,
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
    add(statsText);

    final returnSprite = await game.loadSprite('return.png');
    returnButton = _ReturnButton(
      sprite: returnSprite,
      position: Vector2(20, 50),
      onPressed: () => game.router.pushReplacementNamed('menu'),
    );
    add(returnButton);
  }

  Future<void> _loadPlayerData() async {
    final prefs = await SharedPreferences.getInstance();
    final user = FirebaseAuth.instance.currentUser;

    // Load cached data instantly
    playerName = prefs.getString('playerName') ?? 'Anonymous';
    wins = prefs.getInt('wins') ?? 0;
    losses = prefs.getInt('losses') ?? 0;
    draws = prefs.getInt('draws') ?? 0;

    // Then try to fetch updated data from Firestore
    if (user != null) {
      playerName = user.displayName ?? playerName;
      try {
        final doc = await FirebaseFirestore.instance
            .collection('scores')
            .doc(user.uid)
            .get();

        if (doc.exists) {
          final data = doc.data()!;
          wins = data['wins'] ?? wins;
          losses = data['losses'] ?? losses;
          draws = data['draws'] ?? draws;

          // Save new data back to prefs
          await prefs.setString('playerName', playerName);
          await prefs.setInt('wins', wins);
          await prefs.setInt('losses', losses);
          await prefs.setInt('draws', draws);

          // Update screen text if components already loaded
          if (statsText != null) {
            statsText.text = 'W:$wins  L:$losses  D:$draws';
          }
        }
      } catch (e) {
        print('Offline mode - using cached profile.');
      }
    }
  }
}

class _ReturnButton extends SpriteComponent with TapCallbacks {
  final VoidCallback onPressed;

  _ReturnButton({
    required Sprite sprite,
    required Vector2 position,
    required this.onPressed,
    Vector2? size,
  }) : super(
         sprite: sprite,
         position: position,
         size: size ?? Vector2(50, 50),
         anchor: Anchor.center,
       );

  @override
  void onTapDown(TapDownEvent event) {
    if (SettingsScreen.buttonSoundOn) FlameAudio.play('button.wav');
    onPressed();
  }
}
