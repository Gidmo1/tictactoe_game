import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flame/effects.dart';
import 'models/lobby.dart';

class QuickMatchScreen extends Component with HasGameReference {
  late TextComponent statusText;
  bool searchingStarted = false;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    // Simulate loading progress
    for (int i = 1; i <= 8; i++) {
      await Future.delayed(const Duration(milliseconds: 80));
    }

    try {
      // Background
      final bg = SpriteComponent()
        ..sprite = await game.loadSprite('background.png')
        ..size = game.size
        ..position = Vector2.zero();
      add(bg);
    } catch (e) {}

    // Title
    add(
      TextComponent(
        text: 'Quick Match',
        position: Vector2(game.size.x / 2, 80),
        anchor: Anchor.center,
        textRenderer: TextPaint(
          style: const TextStyle(
            fontSize: 32,
            color: Colors.lightBlueAccent,
            fontWeight: FontWeight.bold,
            shadows: [
              Shadow(blurRadius: 8, color: Colors.black, offset: Offset(0, 2)),
            ],
          ),
        ),
      ),
    );

    // Quick Match button image
    final quickMatchSprite = await game.loadSprite('quick_match.png');
    add(
      SpriteComponent(
        sprite: quickMatchSprite,
        size: Vector2(120, 120),
        position: Vector2(game.size.x / 2, 180),
        anchor: Anchor.center,
      ),
    );

    // Status text for matchmaking
    statusText = TextComponent(
      text: 'Searching for an opponent...',
      position: Vector2(game.size.x / 2, 320),
      anchor: Anchor.center,
      textRenderer: TextPaint(
        style: const TextStyle(
          fontSize: 24,
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
    add(statusText);

    // Return button
    final returnSprite = await game.loadSprite('return.png');
    add(
      _ArcadeButton(
        sprite: returnSprite,
        position: Vector2(60, 60),
        size: Vector2(60, 60),
        onPressed: () {
          if (!searchingStarted) {
            _showConfirmationOverlay();
          }
        },
      ),
    );

    try {
      // Firestore lobby matchmaking
      searchingStarted = true;
      await _findOrCreateLobby();
    } catch (e) {
      statusText.text = 'Matchmaking failed. Please try again.';
    }
  }

  Future<void> _findOrCreateLobby() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      statusText.text = 'You must be signed in to play online.';
      return;
    }
    final lobbyCollection = FirebaseFirestore.instance.collection('lobbies');
    // Try to find an open lobby (not full, not created by this user)
    final query = await lobbyCollection
        .where('open', isEqualTo: true)
        .where('id', isNotEqualTo: user.uid)
        .limit(1)
        .get();
    if (query.docs.isNotEmpty) {
      // Join existing lobby
      final lobby = Lobby.fromJson(query.docs.first.data());
      statusText.text = 'Opponent found! Joining lobby...';
      await lobbyCollection.doc(lobby.id).update({
        'open': false,
        'opponentId': user.uid,
      });
      // Listen for game start (optional)
      _listenForGameStart(lobby.id);
    } else {
      // Create new lobby
      final newLobby = Lobby(
        id: user.uid,
        username: user.displayName ?? user.email ?? 'Unknown',
      );
      await lobbyCollection.doc(newLobby.id).set({
        ...newLobby.toJson(),
        'open': true,
        'opponentId': null,
      });
      statusText.text = 'Waiting for opponent...';
      // Listen for opponent joining
      _listenForGameStart(newLobby.id);
    }
  }

  void _listenForGameStart(String lobbyId) {
    final lobbyDoc = FirebaseFirestore.instance
        .collection('lobbies')
        .doc(lobbyId);
    lobbyDoc.snapshots().listen((snapshot) {
      final data = snapshot.data();
      if (data != null && data['opponentId'] != null) {
        statusText.text = 'Opponent joined! Starting game...';
        // TODO: Trigger game start logic here
      }
    });
  }

  void _showConfirmationOverlay() {
    // Show overlay using confirmation_overlay.png
    add(
      ConfirmationOverlay(
        message: 'Are you sure you want to return?',
        onYes: () {
          // Remove overlay and return to previous screen
          removeWhere((c) => c is ConfirmationOverlay);
          final flameGame = findGame();
          if (flameGame != null) {
            final router = (flameGame as dynamic).router;
            router?.pushNamed('competition');
          }
        },
        onNo: () {
          // Remove overlay only
          removeWhere((c) => c is ConfirmationOverlay);
        },
      ),
    );
  }
}

class ConfirmationOverlay extends PositionComponent with HasGameReference {
  final String message;
  final VoidCallback onYes;
  final VoidCallback onNo;

  ConfirmationOverlay({
    required this.message,
    required this.onYes,
    required this.onNo,
  }) {
    size = Vector2(320, 180);
    position = Vector2(120, 200);
    anchor = Anchor.topLeft;
  }

  @override
  Future<void> onLoad() async {
    final overlaySprite = await game.loadSprite('confirmation_overlay.png');
    add(
      SpriteComponent(
        sprite: overlaySprite,
        size: size,
        position: Vector2.zero(),
      ),
    );
    add(
      TextComponent(
        text: message,
        position: Vector2(size.x / 2, 40),
        anchor: Anchor.topCenter,
        textRenderer: TextPaint(
          style: const TextStyle(
            fontSize: 20,
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
    // Yes button (text only)
    add(
      _TextButton(
        label: 'Yes',
        position: Vector2(size.x / 2 - 60, size.y - 40),
        onPressed: onYes,
      ),
    );
    // No button (text only)
    add(
      _TextButton(
        label: 'No',
        position: Vector2(size.x / 2 + 60, size.y - 40),
        onPressed: onNo,
      ),
    );
  }
}

class _TextButton extends PositionComponent with HasGameReference {
  final String label;
  final VoidCallback onPressed;

  _TextButton({
    required this.label,
    required Vector2 position,
    required this.onPressed,
  }) {
    this.position = position;
    size = Vector2(60, 40);
    anchor = Anchor.center;
  }

  @override
  Future<void> onLoad() async {
    add(
      TextComponent(
        text: label,
        position: Vector2(size.x / 2, size.y / 2),
        anchor: Anchor.center,
        textRenderer: TextPaint(
          style: const TextStyle(
            fontSize: 18,
            color: Colors.amber,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  void onTapDown(TapDownEvent event) {
    onPressed();
  }
}

class _ArcadeButton extends SpriteComponent
    with TapCallbacks, HasGameReference {
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
    Future.delayed(const Duration(milliseconds: 150), onPressed);
  }
}
