import 'dart:io';
import 'dart:math';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/effects.dart';
import 'package:flutter/material.dart';
import 'package:flame_audio/flame_audio.dart';
import 'settings_screen.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'service/competition_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'models/competition.dart';

// Buttons

class _ReturnButton extends SpriteComponent with TapCallbacks {
  final VoidCallback onPressed;
  _ReturnButton({
    required Sprite sprite,
    required Vector2 position,
    required this.onPressed,
  }) : super(
         sprite: sprite,
         position: position,
         size: Vector2(50, 50),
         anchor: Anchor.center,
       );

  @override
  void onTapDown(TapDownEvent event) {
    if (SettingsScreen.buttonSoundOn) FlameAudio.play('button.wav');
    add(ScaleEffect.to(Vector2(0.9, 0.9), EffectController(duration: 0.05)));
    Future.delayed(const Duration(milliseconds: 120), onPressed);
  }
}

class _PressdownButton extends SpriteComponent with TapCallbacks {
  final VoidCallback onPressed;
  _PressdownButton({
    required Sprite sprite,
    required Vector2 position,
    Vector2? size,
    required this.onPressed,
  }) : super(
         sprite: sprite,
         position: position,
         size: size ?? Vector2(200, 60),
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
    Future.delayed(const Duration(milliseconds: 150), onPressed);
  }
}

class _TextButton extends PositionComponent with TapCallbacks {
  final VoidCallback onPressed;
  final String text;
  final double width;
  final double height;

  _TextButton({
    required this.text,
    required Vector2 position,
    required this.onPressed,
    this.width = 180,
    this.height = 48,
  }) : super(
         position: position,
         size: Vector2(width, height),
         anchor: Anchor.center,
       );

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    add(
      RectangleComponent(size: size, paint: Paint()..color = Colors.blueAccent),
    );
    add(
      TextComponent(
        text: text,
        position: Vector2(size.x / 2, size.y / 2),
        anchor: Anchor.center,
        textRenderer: TextPaint(
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  @override
  void onTapDown(TapDownEvent event) {
    if (SettingsScreen.buttonSoundOn) FlameAudio.play('button.wav');
    add(ScaleEffect.to(Vector2(0.95, 0.95), EffectController(duration: 0.06)));
    Future.delayed(const Duration(milliseconds: 150), onPressed);
  }
}

// LEADERBOARD

class LeaderboardCardComponent extends PositionComponent {
  final int rank;
  final String name;
  final int score;
  final Color cardColor;
  final Color textColor;
  final Color? medalColor;
  final double width;
  final double height;

  LeaderboardCardComponent({
    required this.rank,
    required this.name,
    required this.score,
    required Vector2 position,
    required this.cardColor,
    required this.textColor,
    this.medalColor,
    required this.width,
    required this.height,
  }) : super(
         position: position,
         size: Vector2(width, height),
         anchor: Anchor.topLeft,
       );

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    add(RectangleComponent(size: size, paint: Paint()..color = cardColor));

    if (medalColor != null && rank <= 3) {
      final trophySize = 28.0;
      add(
        SpriteComponent(
          sprite: await Sprite.load(
            rank == 1
                ? 'trophy_gold.png'
                : rank == 2
                ? 'trophy_silver.png'
                : 'trophy_bronze.png',
          ),
          size: Vector2(trophySize, trophySize),
          position: Vector2(16, size.y / 2 - trophySize / 2),
        ),
      );
    }

    add(
      TextComponent(
        text: '$rank',
        position: Vector2(60, size.y / 2),
        anchor: Anchor.center,
        textRenderer: TextPaint(
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: medalColor ?? Colors.white,
          ),
        ),
      ),
    );

    add(
      CircleComponent(
        radius: 20,
        position: Vector2(110, size.y / 2),
        anchor: Anchor.center,
        paint: Paint()..color = Colors.blueGrey,
      ),
    );

    add(
      TextComponent(
        text: name,
        position: Vector2(145, size.y / 2),
        anchor: Anchor.centerLeft,
        textRenderer: TextPaint(
          style: TextStyle(
            fontSize: 18,
            color: textColor,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );

    add(
      TextComponent(
        text: '$score XP',
        position: Vector2(width - 16, size.y / 2),
        anchor: Anchor.centerRight,
        textRenderer: TextPaint(
          style: TextStyle(
            fontSize: 18,
            color: const Color.fromARGB(255, 225, 180, 0),
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

class _ScrollableLeaderboardContainer extends PositionComponent
    with DragCallbacks {
  final List<Map<String, dynamic>> entries;
  final double width;
  final double height;
  final double y;
  double scrollOffset = 0;
  double scrollVelocity = 0;
  final double cardHeight = 70;
  List<LeaderboardCardComponent> cardComponents = [];

  _ScrollableLeaderboardContainer({
    required this.entries,
    required this.width,
    required this.height,
    required this.y,
  }) : super(position: Vector2(0, y), size: Vector2(width, height));

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    _buildCards();
  }

  void _buildCards() {
    removeAll(children);
    cardComponents.clear();

    List<Map<String, dynamic>> renderEntries = entries;
    if (entries.isEmpty) {
      renderEntries = List.generate(8, (i) {
        final names = [
          'Alex',
          'Jordan',
          'Sam',
          'Gidmo',
          'Chris',
          'Morgan',
          'Riley',
          'Casey',
          'Jamie',
          'Dakota',
          'Stephen',
          'Daniel',
          'Scott',
        ];
        return {'name': names[i % names.length], 'score': (10 - i) * 50};
      });
    }

    for (int i = 0; i < renderEntries.length; i++) {
      final rank = i + 1;
      final name = renderEntries[i]['name'] ?? 'Player';
      final score = renderEntries[i]['score'] ?? 0;
      final cardColor = rank <= 3
          ? const Color.fromARGB(255, 74, 104, 67)
          : const Color.fromARGB(255, 74, 104, 67);

      final card = LeaderboardCardComponent(
        rank: rank,
        name: name,
        score: score,
        position: Vector2(0, i * cardHeight),
        cardColor: cardColor,
        textColor: Colors.white,
        medalColor: rank <= 3
            ? rank == 1
                  ? Colors.yellow.shade700
                  : rank == 2
                  ? Colors.grey
                  : const Color(0xFFCD7F32)
            : null,
        width: width,
        height: cardHeight - 6,
      );

      cardComponents.add(card);
      add(card);
    }

    _updateCardPositions();
  }

  void _updateCardPositions() {
    for (int i = 0; i < cardComponents.length; i++) {
      cardComponents[i].position = Vector2(0, i * cardHeight - scrollOffset);
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (scrollVelocity.abs() > 0.1) {
      scrollOffset += scrollVelocity * dt;
      scrollVelocity *= 0.92;
      final maxScroll = (entries.length * cardHeight - height).clamp(
        0,
        double.infinity,
      );
      scrollOffset = scrollOffset.clamp(0, maxScroll).toDouble();
      _updateCardPositions();
    }
  }

  @override
  void onDragUpdate(DragUpdateEvent event) {
    scrollOffset -= event.localDelta.y;
    scrollVelocity = -event.localDelta.y * 10;
    final maxScroll = (entries.length * cardHeight - height).clamp(
      0,
      double.infinity,
    );
    scrollOffset = scrollOffset.clamp(0, maxScroll).toDouble();
    _updateCardPositions();
  }
}

// COMPETITION SCREEN

class CompetitionScreen extends Component with HasGameReference {
  List<Map<String, dynamic>> leaderboardEntries = [];
  late SpriteComponent loadingIndicator;
  final FirebaseFunctions functions = FirebaseFunctions.instance;
  bool confettiRunning = false;
  final Random _random = Random();
  final List<Component> _confettiPieces = [];

  void _startConfetti() {
    if (confettiRunning) return;
    confettiRunning = true;
    final size = game.size;

    void spawnConfettiPiece() {
      if (!confettiRunning) return;
      final double confettiSize = 4 + _random.nextDouble() * 6;
      final shapeType = _random.nextInt(3);
      late PositionComponent confetti;
      final paint = Paint()
        ..color = Color.fromARGB(
          255,
          _random.nextInt(256),
          _random.nextInt(256),
          _random.nextInt(256),
        );

      switch (shapeType) {
        case 0:
          confetti = RectangleComponent(
            size: Vector2(confettiSize, confettiSize * 1.5),
            paint: paint,
            position: Vector2(_random.nextDouble() * size.x, -10),
            anchor: Anchor.center,
          );
          break;
        case 1:
          confetti = CircleComponent(
            radius: confettiSize / 2,
            paint: paint,
            position: Vector2(_random.nextDouble() * size.x, -10),
            anchor: Anchor.center,
          );
          break;
        default:
          confetti = PolygonComponent(
            [
              Vector2(0, 0),
              Vector2(confettiSize, 0),
              Vector2(confettiSize / 2, confettiSize),
            ],
            paint: paint,
            position: Vector2(_random.nextDouble() * size.x, -10),
            anchor: Anchor.center,
          );
      }

      _confettiPieces.add(confetti);
      add(confetti);

      final fallDuration = 1.5 + _random.nextDouble() * 1.5;
      confetti.add(
        MoveEffect.to(
          Vector2(confetti.x, size.y + 50),
          EffectController(duration: fallDuration, curve: Curves.linear),
          onComplete: () {
            confetti.removeFromParent();
            _confettiPieces.remove(confetti);
          },
        ),
      );

      confetti.add(
        RotateEffect.by(
          _random.nextDouble() * pi * 4,
          EffectController(duration: fallDuration, curve: Curves.linear),
        ),
      );
      Future.delayed(const Duration(milliseconds: 15), spawnConfettiPiece);
    }

    spawnConfettiPiece();
    Future.delayed(
      const Duration(milliseconds: 2500),
      () => confettiRunning = false,
    );
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    final bg = SpriteComponent()
      ..sprite = await game.loadSprite('leaderboard_background.png')
      ..size = game.size
      ..position = Vector2.zero();
    add(bg);

    loadingIndicator = SpriteComponent()
      ..sprite = await game.loadSprite('loading.png')
      ..size = Vector2(60, 60)
      ..position = game.size / 2
      ..anchor = Anchor.center;
    add(loadingIndicator);
    loadingIndicator.add(
      RotateEffect.by(6.28, EffectController(duration: 1, infinite: true)),
    );

    // Internet check
    bool online = true;
    try {
      final result = await InternetAddress.lookup(
        'example.com',
      ).timeout(const Duration(seconds: 4));
      online = result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } catch (_) {
      online = false;
    }

    if (!online) {
      remove(loadingIndicator);
      // Show retry UI handled here
      return;
    }

    await _showLeaderboardUI();
  }

  Future<void> _showLeaderboardUI() async {
    leaderboardEntries = await _fetchTopPlayers(8);
    remove(loadingIndicator);

    add(
      _ScrollableLeaderboardContainer(
        entries: leaderboardEntries,
        width: game.size.x,
        height: game.size.y - 300,
        y: 160,
      ),
    );

    // Return button
    final returnSprite = await game.loadSprite('return.png');
    add(
      _ReturnButton(
        sprite: returnSprite,
        position: Vector2(24, 60),
        onPressed: () {
          final flameGame = findGame();
          if (flameGame != null)
            (flameGame as dynamic).router?.pushNamed('menu');
        },
      ),
    );

    // TOURNAMENT BUTTON
    final joinSprite = await game.loadSprite('joinatournament.png');
    final playSprite = await game.loadSprite('play.png');
    final buttonWidth = 220.0;
    final buttonHeight = 56.0;
    final bottomStartY = game.size.y - buttonHeight - 10;
    final fbUser = fb.FirebaseAuth.instance.currentUser;
    final svc = CompetitionService();
    final weekId = svc.getCurrentWeekId();
    bool userJoined = false;
    String userLeague = 'bronze';

    if (fbUser != null) {
      final entry = await svc.getUserEntry(weekId, fbUser.uid);
      userJoined = entry != null;
      if (entry?.league != null) userLeague = entry!.league;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      userJoined =
          userJoined || (prefs.getBool('joinedTournament_$weekId') ?? false);
      // If we don't have an entry object, try to read a stored league hint
      userLeague = prefs.getString('player_league') ?? userLeague;
    } catch (_) {}

    void goToTournament() {
      final flameGame = findGame();
      if (flameGame != null)
        (flameGame as dynamic).router?.pushNamed('tournament');
    }

    if (!userJoined) {
      add(
        _PressdownButton(
          sprite: joinSprite,
          position: Vector2(game.size.x / 2, bottomStartY),
          size: Vector2(buttonWidth, buttonHeight),
          onPressed: () async {
            // Allow guest users to join immediately without forcing auth.
            final user = await svc.waitForSignIn(
              timeout: const Duration(seconds: 3),
            );
            try {
              final prefs = await SharedPreferences.getInstance();

              if (user == null) {
                // Create or reuse a persistent guest id so the server can
                // identify the player for the tournament. This id is stored
                // locally only and prefixed with "guest_".
                String guestId = prefs.getString('guest_id') ?? '';
                if (guestId.isEmpty) {
                  guestId = 'guest_${DateTime.now().millisecondsSinceEpoch}';
                  await prefs.setString('guest_id', guestId);
                }

                final entry = CompetitionEntry(
                  userId: guestId,
                  userName: 'Guest',
                  xp: 0,
                  wins: 0,
                  draws: 0,
                  losses: 0,
                  joinedAt: DateTime.now(),
                  league: 'bronze',
                );

                // Mark joined locally so the UI reflects membership.
                await prefs.setBool('joinedTournament_$weekId', true);

                // Try to inform the server but don't block the UX if this
                // fails (some backends may require auth). We swallow errors
                // here so the new user can start matchmaking immediately.
                try {
                  final callable = FirebaseFunctions.instanceFor(
                    region: 'us-central1',
                  ).httpsCallable('joinTournament');
                  await callable.call({
                    'weekId': weekId,
                    'userName': entry.userName,
                    'playerId': entry.userId,
                    'guest': true,
                  });
                } catch (e) {
                  debugPrint(
                    'Guest joinTournament server call failed (non-blocking): $e',
                  );
                }

                goToTournament();
                return;
              }

              // Signed-in user path (unchanged)
              final entry = CompetitionEntry(
                userId: user.uid,
                userName: user.displayName ?? 'Player',
                xp: 0,
                wins: 0,
                draws: 0,
                losses: 0,
                joinedAt: DateTime.now(),
                league: 'bronze',
              );
              await svc.joinTournament(weekId, entry);
              await prefs.setBool('joinedTournament_$weekId', true);
              goToTournament();
            } catch (err) {
              debugPrint('Error while joining tournament: $err');
              // Ensure the user still navigates to the tournament UI so
              // they can start matchmaking locally; server sync can be
              // retried later.
              try {
                final prefs = await SharedPreferences.getInstance();
                await prefs.setBool('joinedTournament_$weekId', true);
              } catch (_) {}
              goToTournament();
            }
          },
        ),
      );
    } else {
      add(
        _PressdownButton(
          sprite: playSprite,
          position: Vector2(game.size.x / 2, bottomStartY),
          size: Vector2(buttonWidth, buttonHeight),
          onPressed: () async {
            final flameGame = findGame();
            if (flameGame != null) {
              try {
                (flameGame as dynamic).pendingTournamentAutoSearch = true;
              } catch (_) {}
            }
            goToTournament();
          },
        ),
      );
    }

    // Badges header (Bronze always unlocked)
    try {
      final badgeBronze = await game.loadSprite('Bronze I.png');
      final badgeSilver = await game.loadSprite(
        userLeague == 'silver' || userLeague == 'gold'
            ? 'Silver II.png'
            : 'Silver II_locked.png',
      );
      final badgeGold = await game.loadSprite(
        userLeague == 'gold' ? 'Gold III.png' : 'Gold III_locked.png',
      );

      // Larger badges
      final badgeSize = Vector2(110, 110);
      final bronzePos = Vector2(60, 130);
      final silverPos = Vector2(190, 100);
      final goldPos = Vector2(320, 90);

      add(
        SpriteComponent(
          sprite: badgeBronze,
          size: badgeSize,
          position: bronzePos,
          anchor: Anchor.center,
        ),
      );
      add(
        SpriteComponent(
          sprite: badgeSilver,
          size: badgeSize,
          position: silverPos,
          anchor: Anchor.center,
        ),
      );
      add(
        SpriteComponent(
          sprite: badgeGold,
          size: badgeSize,
          position: goldPos,
          anchor: Anchor.center,
        ),
      );
    } catch (e) {
      // If badges fail to load don't crash the screen.
      print('Badge header load failed: $e');
    }
  }

  Future<List<Map<String, dynamic>>> _fetchTopPlayers(int limit) async {
    try {
      final HttpsCallable callable = functions.httpsCallable('getLeaderboard');
      final result = await callable.call({'limit': limit});
      final List<dynamic> data = result.data ?? [];
      return data
          .map((e) => {'name': e['name'] ?? 'Player', 'score': e['score'] ?? 0})
          .toList();
    } catch (_) {
      return [];
    }
  }
}
