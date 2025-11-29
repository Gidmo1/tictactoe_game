import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
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
  String league = 'bronze';
  List<String> trophies = [];

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    debugPrint('ProfileScreen: onLoad starting');

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

    // Avatar - prefer chosen avatar if user selected one. Do not use
    // a generic 'profile.png' fallback; if none chosen, show a placeholder.
    Sprite? avatarSprite;
    try {
      final prefs = await SharedPreferences.getInstance();
      final chosen = prefs.getString('chosen_avatar') ?? '';
      if (chosen.isNotEmpty) {
        // Try multiple asset keys for robustness
        final candidates = [
          'assets/images/$chosen.png',
          'images/$chosen.png',
          '$chosen.png',
        ];
        for (final key in candidates) {
          try {
            avatarSprite = await game.loadSprite(key);
            break;
          } catch (_) {}
        }
      }
    } catch (_) {}

    if (avatarSprite != null) {
      avatar = SpriteComponent(
        sprite: avatarSprite,
        size: Vector2(100, 100),
        position: Vector2(game.size.x / 2 - 50, 140),
      );
      add(avatar);
    }

    // Load cached and online user info
    await _loadPlayerData();
    debugPrint(
      'ProfileScreen: onLoad after _loadPlayerData playerName="$playerName"',
    );

    // Fetch and display the current Firebase user name if available
    final user = FirebaseAuth.instance.currentUser;
    if (user != null &&
        user.displayName != null &&
        user.displayName!.isNotEmpty) {
      playerName = user.displayName!;
    }

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

    // Pencil/edit button beside the name to open the profile editor
    try {
      final editBtn = _NameEditButton(
        position: Vector2(game.size.x / 2 + 100, 250),
        gameRef: game,
      );
      add(editBtn);
    } catch (_) {}

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

    // Trophies section
    try {
      if (trophies.isEmpty) {
        final noTrophies = TextComponent(
          text:
              'No trophies yet. Play and win online matches to earn trophies!',
          position: Vector2(game.size.x / 2, 330),
          anchor: Anchor.center,
          textRenderer: TextPaint(
            style: const TextStyle(color: Colors.white, fontSize: 12),
          ),
        );
        add(noTrophies);
      } else {
        // Display trophies
        final startX = game.size.x / 2 - (trophies.length * 48) / 2;
        for (int i = 0; i < trophies.length; i++) {
          final key = trophies[i];
          try {
            final tSprite = await game.loadSprite('$key.png');
            final tc = SpriteComponent(
              sprite: tSprite,
              size: Vector2(44, 44),
              position: Vector2(startX + i * 48, 340),
              anchor: Anchor.topLeft,
            );
            add(tc);
          } catch (_) {}
        }
      }
    } catch (_) {}

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

    // Load saved data instantly
    final storedName = prefs.getString('playerName');
    debugPrint('ProfileScreen._loadPlayerData: storedName=$storedName');
    playerName = (storedName != null && storedName.trim().isNotEmpty)
        ? storedName
        : 'Anonymous';
    debugPrint(
      'ProfileScreen._loadPlayerData: playerName after prefs="$playerName"',
    );
    wins = prefs.getInt('wins') ?? 0;
    losses = prefs.getInt('losses') ?? 0;
    draws = prefs.getInt('draws') ?? 0;

    // Then try to fetch updated data from Firestore
    if (user != null) {
      final fd = user.displayName;
      if (fd != null && fd.trim().isNotEmpty) {
        playerName = fd;
        debugPrint(
          'ProfileScreen._loadPlayerData: using Firebase displayName="$playerName"',
        );
      } else {
        debugPrint(
          'ProfileScreen._loadPlayerData: Firebase displayName empty, keeping prefs value="$playerName"',
        );
      }
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

          // Save new data back to shared preferences
          await prefs.setString('playerName', playerName);
          await prefs.setInt('wins', wins);
          await prefs.setInt('losses', losses);
          await prefs.setInt('draws', draws);

          // Fetch persistent profile (league) and awards/trophies
          try {
            final profileDoc = await FirebaseFirestore.instance
                .collection('playerProfiles')
                .doc(user.uid)
                .get();
            if (profileDoc.exists) {
              final pd = profileDoc.data()!;
              league = (pd['league'] as String?) ?? league;
            }

            final awardsSnap = await FirebaseFirestore.instance
                .collection('playerProfiles')
                .doc(user.uid)
                .collection('awards')
                .get();
            trophies = [];
            for (final a in awardsSnap.docs) {
              final ad = a.data();
              if (ad['trophy'] != null) trophies.add(ad['trophy'] as String);
            }
          } catch (_) {}
        }
      } catch (e) {
        debugPrint('Offline mode - using cached profile: $e');
      }
    }
  }

  // Public method to refresh the displayed name and avatar from SharedPreferences.
  Future<void> refreshFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // Update name
      final stored = prefs.getString('playerName');
      debugPrint('ProfileScreen.refreshFromPrefs: stored="$stored"');
      playerName = (stored != null && stored.trim().isNotEmpty)
          ? stored
          : playerName;
      debugPrint(
        'ProfileScreen.refreshFromPrefs: updating nameText to "$playerName"',
      );
      try {
        nameText.text = playerName;
      } catch (e) {
        debugPrint(
          'ProfileScreen.refreshFromPrefs: failed to set nameText: $e',
        );
      }

      // Update avatar sprite if chosen
      final chosen = prefs.getString('chosen_avatar') ?? '';
      if (chosen.isNotEmpty) {
        try {
          final spr = await game.loadSprite('$chosen.png');
          avatar.sprite = spr;
        } catch (_) {}
      }
    } catch (_) {}
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

class _NameEditButton extends PositionComponent with TapCallbacks {
  final TicTacToeGame gameRef;
  final TextPaint _textPaint = TextPaint(
    style: const TextStyle(
      color: Colors.white,
      fontSize: 14,
      fontWeight: FontWeight.bold,
    ),
  );

  _NameEditButton({required Vector2 position, required this.gameRef})
    : super(position: position, size: Vector2(64, 28), anchor: Anchor.center);

  @override
  void render(Canvas canvas) {
    // Draw rounded rect background
    final rect =
        Offset(position.x - size.x / 2, position.y - size.y / 2) &
        Size(size.x, size.y);
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(8));
    final paint = Paint()..color = const Color(0x66000000);
    canvas.drawRRect(rrect, paint);

    _textPaint.render(canvas, 'Edit', position - Vector2(18, 6));
    super.render(canvas);
  }

  @override
  void onTapDown(TapDownEvent event) {
    try {
      if (SettingsScreen.buttonSoundOn) FlameAudio.play('button.wav');
      gameRef.overlays.add('edit_profile_inline');
    } catch (_) {}
  }
}
