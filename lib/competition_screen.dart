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
import 'package:cloud_firestore/cloud_firestore.dart';
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

// Text button and retry.png to retry.s
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
          style: TextStyle(
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
    _bounce();
    Future.delayed(const Duration(milliseconds: 150), onPressed);
  }

  void _bounce() {
    add(ScaleEffect.to(Vector2(0.95, 0.95), EffectController(duration: 0.06)));
  }
}

// Leaderboard Card

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

// Scrollable Leaderboard
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

    // Show dummy people when the leaderboard is empty.
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

      final Color cardColor = rank <= 3
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

// Competition screen
class CompetitionScreen extends Component with HasGameReference {
  List<Map<String, dynamic>> leaderboardEntries = [];
  late SpriteComponent loadingIndicator;
  final FirebaseFunctions functions = FirebaseFunctions.instance;
  // Confetti for award celebration
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

    Future.delayed(const Duration(milliseconds: 2500), () {
      confettiRunning = false;
    });
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    final bg = SpriteComponent()
      ..sprite = await game.loadSprite('leaderboard_background.png')
      ..size = game.size
      ..position = Vector2.zero();
    add(bg);

    // Loading indicator
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

      // Try to show a retry image button if network available
      try {
        final retrySprite = await game.loadSprite('retry.png');
        late final _PressdownButton retryButton;
        retryButton = _PressdownButton(
          sprite: retrySprite,
          position: game.size / 2 + Vector2(0, 40),
          size: Vector2(120, 120),
          onPressed: () async {
            // Connectivity re-check
            bool nowOnline = true;
            try {
              final result = await InternetAddress.lookup(
                'example.com',
              ).timeout(const Duration(seconds: 4));
              nowOnline = result.isNotEmpty && result[0].rawAddress.isNotEmpty;
            } catch (_) {
              nowOnline = false;
            }

            if (nowOnline) {
              // remove the offline UI and continue
              retryButton.removeFromParent();
              add(loadingIndicator);
              await _showLeaderboardUI();
            }
          },
        );

        // Also add a short message above the retry button
        final offlineText = TextComponent(
          text: 'No internet connection. Tap to retry.',
          position: game.size / 2 - Vector2(0, 30),
          anchor: Anchor.center,
          textRenderer: TextPaint(
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        );
        add(offlineText);
        add(retryButton);
      } catch (e) {
        // If the retry sprite isn't available, fall back to a simple text
        // message and a Retry text button.
        final offlineText = TextComponent(
          text: 'No internet connection.\nPlease check your connection.',
          position: game.size / 2 - Vector2(0, 30),
          anchor: Anchor.center,
          textRenderer: TextPaint(
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        );
        add(offlineText);

        // Retry button below the message
        late final _TextButton retryButton;
        retryButton = _TextButton(
          text: 'Retry',
          position: (game.size / 2) + Vector2(0, 40),
          onPressed: () async {
            // Connectivity re-check
            bool nowOnline = true;
            try {
              final result = await InternetAddress.lookup(
                'example.com',
              ).timeout(const Duration(seconds: 4));
              nowOnline = result.isNotEmpty && result[0].rawAddress.isNotEmpty;
            } catch (_) {
              nowOnline = false;
            }

            if (nowOnline) {
              // remove the offline UI stuffs and continue
              offlineText.removeFromParent();
              retryButton.removeFromParent();
              add(loadingIndicator);
              await _showLeaderboardUI();
            }
          },
        );
        add(retryButton);
      }

      return;
    }

    // If online, show the leaderboadUi
    await _showLeaderboardUI();
  }

  Future<void> _showLeaderboardUI() async {
    // Fetch leaderboard
    leaderboardEntries = await _fetchTopPlayers(8); // top 8

    remove(loadingIndicator);

    final leaderboardStartY = 120.0;
    final leaderboardHeight = game.size.y - leaderboardStartY - 180.0;
    add(
      _ScrollableLeaderboardContainer(
        entries: leaderboardEntries,
        width: game.size.x,
        height: leaderboardHeight,
        y: leaderboardStartY + 40,
      ),
    );

    // Return Button
    final returnSprite = await game.loadSprite('return.png');
    add(
      _ReturnButton(
        sprite: returnSprite,
        position: Vector2(24, 60),
        onPressed: () {
          final flameGame = findGame();
          if (flameGame != null) {
            (flameGame as dynamic).router?.pushNamed('menu');
          }
        },
      ),
    );

    // Join / Play Tournament Button
    final joinSprite = await game.loadSprite('joinatournament.png');
    final playSprite = await game.loadSprite('play.png');
    final buttonWidth = 220.0;
    final buttonHeight = 56.0;
    final bottomStartY = game.size.y - buttonHeight - 10;

    final fb.User? fbUser = fb.FirebaseAuth.instance.currentUser;
    final svc = CompetitionService();
    final FirebaseFunctions functions = FirebaseFunctions.instanceFor(
      region: 'us-central1',
    );
    final weekId = svc.getCurrentWeekId();

    bool userJoined = false;
    // First try cloud function
    if (fbUser != null) {
      final entry = await svc.getUserEntry(weekId, fbUser.uid);
      userJoined = entry != null;
    }

    //If cloud function didn't find an entry, use the player side to join a tournament, so play button will show instead of join tournament button after the user joins
    try {
      final prefs = await SharedPreferences.getInstance();
      final localJoined = prefs.getBool('joinedTournament_$weekId') ?? false;
      userJoined = userJoined || localJoined;
    } catch (_) {}

    // Determine current user's league (the default is bronze for beginners or mew players in the game)
    String userLeague = 'bronze';
    try {
      if (fbUser != null) {
        final entry = await svc.getUserEntry(weekId, fbUser.uid);
        if (entry != null && entry.league.isNotEmpty) {
          userLeague = entry.league.toLowerCase();
        } else {
          // Try persistent profile as fallback
          final profileSnap = await FirebaseFirestore.instance
              .collection('playerProfiles')
              .doc(fbUser.uid)
              .get();
          if (profileSnap.exists && profileSnap.data()?['league'] != null) {
            userLeague = (profileSnap.data()?['league'] as String)
                .toLowerCase();
          }
        }
      }
    } catch (_) {
      userLeague = 'bronze';
    }

    // League sprites (use unlocked images for the league the user is currently in and the league the user has passed. Locked images for the league the user has not reached)
    final goldSprite = await Sprite.load(
      userLeague == 'gold' ? 'Gold III.png' : 'Gold III_locked.png',
    );
    final silverSprite = await Sprite.load(
      (userLeague == 'gold' || userLeague == 'silver')
          ? 'Silver II.png'
          : 'Silver II_locked.png',
    );
    final bronzeSprite = await Sprite.load('Bronze I.png');

    addAll([
      SpriteComponent(
        sprite: goldSprite,
        size: Vector2(120, 120),
        position: Vector2(300, 80),
        anchor: Anchor.center,
      ),
      SpriteComponent(
        sprite: silverSprite,
        size: Vector2(110, 110),
        position: Vector2(180, 90),
        anchor: Anchor.center,
      ),
      SpriteComponent(
        sprite: bronzeSprite,
        size: Vector2(120, 120),
        position: Vector2(60, 120),
        anchor: Anchor.center,
      ),
    ]);

    // Check if current user has a new award for this week and show popup
    if (fbUser != null) {
      try {
        final awardDoc = await FirebaseFirestore.instance
            .collection('playerProfiles')
            .doc(fbUser.uid)
            .collection('awards')
            .doc(weekId)
            .get();
        if (awardDoc.exists) {
          final data = awardDoc.data();
          if (data != null && data['read'] == false) {
            final trophyKey = (data['trophy'] as String?) ?? 'trophy_gold';
            final message =
                (data['message'] as String?) ?? 'You won this week!';

            // start confetti celebration
            _startConfetti();

            // Show award overlay
            final trophySprite = await Sprite.load('${trophyKey}.png');
            // Use the confirmation-style overlay if available, fall back to leaderboard background
            Sprite overlaySprite;
            try {
              overlaySprite = await Sprite.load('confirmation_overlay.png');
            } catch (_) {
              overlaySprite = await Sprite.load('leaderboard_background.png');
            }
            final overlayBg = SpriteComponent()
              ..sprite = overlaySprite
              ..size = Vector2(game.size.x * 0.9, game.size.y * 0.5)
              ..position = Vector2(game.size.x * 0.05, game.size.y * 0.2)
              ..anchor = Anchor.topLeft
              ..priority = 1000;

            final trophyComp = SpriteComponent(
              sprite: trophySprite,
              size: Vector2(140, 140),
              // place the trophy centered inside the overlay
              position: Vector2(game.size.x / 2, game.size.y * 0.32),
              anchor: Anchor.center,
              priority: 1001,
            );

            final msg = TextComponent(
              text: message,
              textRenderer: TextPaint(
                style: const TextStyle(color: Colors.white, fontSize: 18),
              ),
              position: Vector2(game.size.x / 2, game.size.y * 0.45),
              anchor: Anchor.center,
              priority: 1001,
            );

            // Claim button. If the sprite is missing, use a text button
            _PressdownButton? claimButtonRef;
            try {
              final claimSprite = await game.loadSprite('claim.png');
              final claimY = overlayBg.position.y + overlayBg.size.y - 40;
              final claimButtonLocal = _PressdownButton(
                sprite: claimSprite,
                position: Vector2(game.size.x / 2, claimY),
                size: Vector2(180, 56),
                onPressed: () async {
                  try {
                    // mark award read via Cloud Function to keep writes and avoid player side to write
                    final callable = functions.httpsCallable('markAwardRead');
                    await callable.call({
                      'playerId': fbUser.uid,
                      'weekId': weekId,
                    });
                  } catch (_) {}
                  // remove overlay components
                  overlayBg.removeFromParent();
                  trophyComp.removeFromParent();
                  msg.removeFromParent();
                  claimButtonRef?.removeFromParent();
                },
              );
              claimButtonRef = claimButtonLocal;
              add(overlayBg);
              add(trophyComp);
              add(msg);
              add(claimButtonLocal);
            } catch (_) {
              // If sprite load failed, use a text button for the user to be able to claim their trophy rewards.
              final claimY = overlayBg.position.y + overlayBg.size.y - 40;
              final textBtn = _TextButton(
                text: 'Claim',
                position: Vector2(game.size.x / 2, claimY),
                onPressed: () async {
                  try {
                    final callable = functions.httpsCallable('markAwardRead');
                    await callable.call({
                      'playerId': fbUser.uid,
                      'weekId': weekId,
                    });
                  } catch (_) {}
                  overlayBg.removeFromParent();
                  trophyComp.removeFromParent();
                  msg.removeFromParent();
                },
              );
              add(overlayBg);
              add(trophyComp);
              add(msg);
              add(textBtn);
            }
          }
        }
      } catch (e) {
        print('Error checking award doc: $e');
      }
    }

    // Helper to push tournament route
    void goToTournament() {
      final flameGame = findGame();
      if (flameGame != null) {
        (flameGame as dynamic).router?.pushNamed('tournament');
      }
    }

    if (!userJoined) {
      add(
        _PressdownButton(
          sprite: joinSprite,
          position: Vector2(game.size.x / 2, bottomStartY),
          size: Vector2(buttonWidth, buttonHeight),
          onPressed: () async {
            // Ensure auth is stable and token refreshed before calling the server
            final user = await svc.waitForSignIn();
            if (user == null) {
              try {
                ScaffoldMessenger.of(game.buildContext!).showSnackBar(
                  const SnackBar(
                    content: Text('Please sign in to join the tournament.'),
                  ),
                );
              } catch (_) {}
              return;
            }

            // Create entry and switch to Play
            final entry = CompetitionEntry(
              userId: user.uid,
              userName: user.displayName ?? 'Player',
              xp: 0,
              wins: 0,
              draws: 0,
              losses: 0,
              joinedAt: DateTime.now(),
              league: '$userLeague',
            );
            try {
              await svc.joinTournament(weekId, entry);
              // Returning to the Competition screen shows Play immediately even if the server-side(cloud function) entry is not visible yet
              try {
                final prefs = await SharedPreferences.getInstance();
                await prefs.setBool('joinedTournament_$weekId', true);
              } catch (_) {}
              // replace this button with Play: push tournament route
              goToTournament();
            } catch (e) {
              // Show an error and allow the user to retry.
              try {
                ScaffoldMessenger.of(game.buildContext!).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Could not join tournament. Please try again.',
                    ),
                  ),
                );
              } catch (_) {}
            }
          },
        ),
      );
    } else {
      // show Play button in same position
      add(
        _PressdownButton(
          sprite: playSprite,
          position: Vector2(game.size.x / 2, bottomStartY),
          size: Vector2(buttonWidth, buttonHeight),
          onPressed: () async {
            // when user pressed play: record an auto search request in both the in-memory game flag and a SharedPreferences key so the Tournament screen sees the request even if the game mode isn't accessible at the moment of navigation.
            final flameGame = findGame();
            if (flameGame != null) {
              try {
                (flameGame as dynamic).pendingTournamentAutoSearch = true;
                debugPrint(
                  'competition: Play pressed -> pendingTournamentAutoSearch set on game',
                );
              } catch (_) {}
            }

            // Use in-memory flag; router triggers matchmaking on route change.
            debugPrint('competition: navigating to tournament route');
            goToTournament();
          },
        ),
      );
    }
  }

  Future<List<Map<String, dynamic>>> _fetchTopPlayers(int limit) async {
    try {
      final HttpsCallable callable = functions.httpsCallable(
        'getLeaderboard',
      ); // Cloud function
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
