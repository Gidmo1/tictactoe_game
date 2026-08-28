import 'dart:ui' as ui;
import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame_audio/flame_audio.dart';
import 'package:flutter/material.dart' hide Route;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tictactoe_game/tictactoe.dart';
import 'package:tictactoe_game/components/button.dart';
import 'game_themes/theme_store.dart';
import 'game_themes/theme.dart';
import 'settings_screen.dart';

class ProfileScreen extends Component with HasGameReference<TicTacToeGame> {
  late SpriteComponent avatar;
  late TextComponent nameText;
  late TextComponent statsText;
  late TextComponent onlineDetailText;
  late TextComponent offlineStatsText;
  late TextComponent offlineDetailText;
  late _ProfileBackButton returnButton;
  ButtonComponent? _signInButton;
  StreamSubscription<AuthState>? _authSubscription;

  String playerName = 'Anonymous';
  int wins = 0;
  int losses = 0;
  int draws = 0;
  int offlineWins = 0;
  int offlineLosses = 0;
  int offlineDraws = 0;
  String league = 'bronze';
  List<String> trophies = [];

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen((
      state,
    ) {
      if (state.event == AuthChangeEvent.signedIn) {
        _signInButton?.removeFromParent();
        _signInButton = null;
        refreshFromSupabase();
      }
    });

    debugPrint('ProfileScreen: onLoad starting');

    add(_ProfileBackdrop(size: game.size, theme: ThemeStore.current));
    add(
      TextComponent(
        text: 'PROFILE',
        position: Vector2(game.size.x / 2, 72),
        anchor: Anchor.center,
        textRenderer: TextPaint(
          style: TextStyle(
            color: ThemeStore.current.contrastColor,
            fontSize: 28,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );

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

    // Fetch and display the current Supabase user name if available
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null &&
        user.userMetadata?['name'] != null &&
        (user.userMetadata?['name'] as String).isNotEmpty) {
      playerName = user.userMetadata!['name'] as String;
    }

    // Player name and stats
    nameText = TextComponent(
      text: playerName,
      position: Vector2(game.size.x / 2, 250),
      anchor: Anchor.center,
      textRenderer: TextPaint(
        style: TextStyle(
          fontSize: 20,
          color: ThemeStore.current.textColor,
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
      text: 'ONLINE MATCHES',
      position: Vector2(game.size.x / 2, 286),
      anchor: Anchor.center,
      textRenderer: TextPaint(
        style: TextStyle(
          fontSize: 16,
          color: ThemeStore.current.textColor,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
    add(statsText);

    onlineDetailText = TextComponent(
        text: 'W:$wins          L:$losses          D:$draws',
        position: Vector2(game.size.x / 2, 316),
        anchor: Anchor.center,
        textRenderer: TextPaint(
          style: TextStyle(
            color: ThemeStore.current.textColor,
            fontSize: 17,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    add(onlineDetailText);

    offlineStatsText = TextComponent(
      text: 'OFFLINE MATCHES',
      position: Vector2(game.size.x / 2, 364),
      anchor: Anchor.center,
      textRenderer: TextPaint(
        style: TextStyle(
          color: ThemeStore.current.gridColor,
          fontSize: 14,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
    add(offlineStatsText);

    offlineDetailText = TextComponent(
      text: 'W:$offlineWins          L:$offlineLosses          D:$offlineDraws',
      position: Vector2(game.size.x / 2, 394),
      anchor: Anchor.center,
      textRenderer: TextPaint(
        style: TextStyle(
          color: ThemeStore.current.textColor,
          fontSize: 17,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
    add(offlineDetailText);

    if (Supabase.instance.client.auth.currentUser == null) {
      _signInButton = ButtonComponent(
        label: 'SIGN IN',
        position: Vector2(game.size.x / 2, 445),
        size: Vector2(150, 42),
        theme: ThemeStore.current,
        onPressed: () => game.overlays.add('auth_gate'),
      );
      add(_signInButton!);
    }

    // Trophies section
    try {
      if (trophies.isEmpty) {
        final signedOut = Supabase.instance.client.auth.currentUser == null;
        final noTrophies = TextComponent(
          text:
              'No trophies yet. Play and win online matches to earn trophies!',
          position: Vector2(
            game.size.x / 2,
            signedOut || offlineWins + offlineLosses + offlineDraws > 0
                ? 500
                : 470,
          ),
          anchor: Anchor.center,
          textRenderer: TextPaint(
            style: TextStyle(
              color: ThemeStore.current.contrastColor,
              fontSize: 12,
            ),
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

    returnButton = _ProfileBackButton(
      position: Vector2(20, 50),
      onPressed: () => game.router.pushReplacementNamed('menu'),
    );
    add(returnButton);
  }

  @override
  void onRemove() {
    _authSubscription?.cancel();
    super.onRemove();
  }

  Future<void> _loadPlayerData() async {
    final prefs = await SharedPreferences.getInstance();
    final user = Supabase.instance.client.auth.currentUser;

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
    offlineWins = prefs.getInt('offline_wins') ?? 0;
    offlineLosses = prefs.getInt('offline_losses') ?? 0;
    offlineDraws = prefs.getInt('offline_draws') ?? 0;

    // Then try to fetch updated data from Supabase.
    if (user != null) {
      final fd = user.userMetadata?['name'] as String?;
      if (fd != null && fd.trim().isNotEmpty) {
        playerName = fd;
        debugPrint(
          'ProfileScreen._loadPlayerData: using Supabase displayName="$playerName"',
        );
      } else {
        debugPrint(
          'ProfileScreen._loadPlayerData: Supabase displayName empty, keeping prefs value="$playerName"',
        );
      }
      try {
        final profile = await Supabase.instance.client
            .from('profiles')
            .select('username, tier, wins, losses, draws')
            .eq('id', user.id)
            .maybeSingle();

        if (profile != null) {
          playerName = (profile['username'] as String?) ?? playerName;
          league = (profile['tier'] as String?) ?? league;

          final onlineScores = await Supabase.instance.client
              .from('scores')
              .select('result, opponent_type')
              .eq('player_id', user.id)
              .neq('opponent_type', 'computer');
          wins = 0;
          losses = 0;
          draws = 0;
          for (final score in onlineScores) {
            switch (score['result']) {
              case 'win':
                wins++;
              case 'loss':
                losses++;
              case 'draw':
                draws++;
            }
          }

          // Save new data back to shared preferences
          await prefs.setString('playerName', playerName);
          await prefs.setInt('wins', wins);
          await prefs.setInt('losses', losses);
          await prefs.setInt('draws', draws);
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

  Future<void> refreshFromSupabase() async {
    await _loadPlayerData();
    if (!isMounted) return;
    nameText.text = playerName;
    statsText.text = 'ONLINE MATCHES';
    onlineDetailText.text = 'W:$wins          L:$losses          D:$draws';
    offlineStatsText.text = 'OFFLINE MATCHES';
    offlineDetailText.text =
      'W:$offlineWins          L:$offlineLosses          D:$offlineDraws';
  }
}

class _ProfileBackdrop extends Component {
  final Vector2 size;
  final GameTheme theme;

  _ProfileBackdrop({required this.size, required this.theme});

  @override
  void render(Canvas canvas) {
    final background = ui.Paint()
      ..shader = ui.Gradient.linear(const Offset(0, 0), Offset(0, size.y), [
        theme.boardBackground,
        theme.buttonBase,
      ]);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.x, size.y), background);

    final panelRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(12, 116, size.x - 24, 414),
      const Radius.circular(14),
    );
    canvas.drawRRect(
      panelRect,
      ui.Paint()..color = theme.boardBackground.withValues(alpha: 0.92),
    );

    final wood = ui.Paint()
      ..color = const Color(0xFF8B5E3C)
      ..style = ui.PaintingStyle.stroke
      ..strokeWidth = 5;
    canvas.drawRRect(panelRect, wood);

    final gold = ui.Paint()
      ..color = const Color(0xFFD4AF37)
      ..style = ui.PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawRRect(panelRect, gold);
    super.render(canvas);
  }
}

class _ProfileBackButton extends PositionComponent with TapCallbacks {
  final VoidCallback onPressed;

  _ProfileBackButton({required Vector2 position, required this.onPressed})
    : super(position: position, size: Vector2(52, 40), anchor: Anchor.center);

  @override
  void render(Canvas canvas) {
    final fill = Paint()..color = const Color(0x66000000);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, size.x, size.y),
        const Radius.circular(8),
      ),
      fill,
    );
    final stroke = Paint()
      ..color = const Color(0xFFD4AF37)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(const Offset(30, 10), const Offset(18, 20), stroke);
    canvas.drawLine(const Offset(18, 20), const Offset(30, 30), stroke);
    super.render(canvas);
  }

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
