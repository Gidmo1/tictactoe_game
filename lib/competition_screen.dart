import 'dart:io';

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
import 'dart:convert';
import 'models/competition.dart';
import 'components/loading_placeholder.dart';

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

/*class _TextButton extends PositionComponent with TapCallbacks {
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
}*/

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

    // Rank / medal (for top 3 we attempt to show a trophy sprite)
    final rankPos = Vector2(48, size.y / 2);
    add(
      TextComponent(
        text: '$rank',
        position: rankPos,
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

    if (medalColor != null && rank <= 3) {
      // Try to load a small trophy sprite for top ranks; non-fatal if missing.
      final trophySize = 28.0;
      final spriteName = rank == 1
          ? 'trophy_gold.png'
          : rank == 2
          ? 'trophy_silver.png'
          : 'trophy_bronze.png';
      try {
        final trophy = await Sprite.load(spriteName);
        add(
          SpriteComponent(
            sprite: trophy,
            size: Vector2(trophySize, trophySize),
            position: Vector2(20, size.y / 2),
            anchor: Anchor.center,
          ),
        );
      } catch (_) {
        // ignore missing sprite
      }
    }

    // Avatar circle
    add(
      CircleComponent(
        radius: 20,
        position: Vector2(110, size.y / 2),
        anchor: Anchor.center,
        paint: Paint()..color = Colors.blueGrey,
      ),
    );

    // Player name
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

    // Score on the right
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
    await _buildCards();
  }

  Future<void> _buildCards() async {
    removeAll(children);
    cardComponents.clear();

    List<Map<String, dynamic>> renderEntries = entries;
    // Fallback: populate a minimal local leaderboard when fewer than 8 entries.
    if (entries.length < 8) {
      final fb.User? user = fb.FirebaseAuth.instance.currentUser;
      final String userName = user?.displayName ?? 'You';

      final List<String> aiNames = [
        'Astra',
        'Boreal',
        'Cirrus',
        'Dynamo',
        'Echo',
        'Falco',
        'GizmoBot',
      ];

      renderEntries = [];
      // If server provided any entry for the current user, preserve their score
      int userScore = 0;
      try {
        final uid = user?.uid ?? '';
        if (uid.isNotEmpty) {
          dynamic match;
          try {
            match = entries.firstWhere((e) => (e['playerId'] ?? '') == uid);
          } catch (_) {
            match = null;
          }
          if (match != null && match is Map && match.containsKey('score')) {
            userScore = match['score'] ?? 0;
          }
        }
      } catch (_) {}

      // Support a local debug override for the user's displayed score (useful
      // for testing). If set, respect that value instead of server score.
      try {
        final prefs = await SharedPreferences.getInstance();
        final enabled = prefs.getBool('debug_force_score_enabled') ?? false;
        if (enabled) {
          final forced = prefs.getInt('debug_force_score');
          if (forced != null) userScore = forced;
        }
      } catch (_) {}

      renderEntries.add({'name': userName, 'score': userScore});
      for (int i = 0; i < aiNames.length; i++) {
        renderEntries.add({'name': aiNames[i], 'score': (100 - i * 5)});
      }
    }

    // Deduplicate entries by playerId (preferred) or by name to avoid repeating names
    final Map<String, Map<String, dynamic>> uniqueById = {};
    final Set<String> seenNames = {};
    final List<Map<String, dynamic>> normalized = [];

    for (final e in renderEntries) {
      final id = (e['playerId'] ?? '') as String? ?? '';
      final name = (e['name'] ?? '') as String? ?? '';
      final score = (e['score'] ?? 0) as int;
      if (id.isNotEmpty) {
        final prev = uniqueById[id];
        if (prev == null || (prev['score'] ?? 0) < score) {
          uniqueById[id] = {'playerId': id, 'name': name, 'score': score};
        }
      } else {
        // if no id, ensure we don't duplicate by name
        if (!seenNames.contains(name)) {
          seenNames.add(name);
          normalized.add({'playerId': '', 'name': name, 'score': score});
        }
      }
    }

    // Combine id-based and name-based entries
    normalized.addAll(uniqueById.values);

    // Sort by score descending
    normalized.sort((a, b) => (b['score'] as int).compareTo(a['score'] as int));
    // Replace placeholder names (e.g., 'player_') with friendly defaults.
    final List<String> replacementAi = [
      'Astra',
      'Boreal',
      'Cirrus',
      'Dynamo',
      'Echo',
      'Falco',
      'Gizmo',
      'Helix',
      'Ion',
      'Juno',
    ];
    int replIdx = 0;

    for (int i = 0; i < normalized.length; i++) {
      final rank = i + 1;
      var name = normalized[i]['name'] ?? 'Player';
      try {
        final lower = name.toString().toLowerCase();
        if (lower.startsWith('player') || lower.contains('nasj')) {
          // replace with a friendly ai name
          name = replacementAi[replIdx % replacementAi.length];
          replIdx++;
        }
      } catch (_) {}
      final score = normalized[i]['score'] ?? 0;
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
  late LoadingPlaceholder loadingPlaceholder;
  // cached leaderboard UI shown immediately if stored snapshot exists
  Component? _cachedLeaderboardContainer;
  final FirebaseFunctions functions = FirebaseFunctions.instance;
  // When true, show a local dummy leaderboard immediately and skip network.
  // Useful for fast local testing or when you want an instant UI.
  bool forceDummyLeaderboard = true;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    // Loading placeholder (draws background.png and a rotating loading.png
    // if available). Avoid using rect shapes so visuals come from assets.
    loadingPlaceholder = LoadingPlaceholder(size: game.size);
    add(loadingPlaceholder);
    add(loadingPlaceholder);

    // Try to load cached leaderboard from local storage
    try {
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getString('cached_leaderboard');
      if (cached != null && cached.isNotEmpty) {
        try {
          final List<dynamic> raw = jsonDecode(cached) as List<dynamic>;
          final List<Map<String, dynamic>> entries = raw.map((e) {
            if (e is Map<String, dynamic>) return e;
            return Map<String, dynamic>.from(e as Map);
          }).toList();

          // show cached leaderboard container immediately
          _cachedLeaderboardContainer = _ScrollableLeaderboardContainer(
            entries: entries,
            width: game.size.x,
            height: game.size.y - 300,
            y: 160,
          );
          _cachedLeaderboardContainer!.priority = 100;
          add(_cachedLeaderboardContainer!);
        } catch (_) {}
      }
    } catch (_) {}

    // Load background image asynchronously
    Future.microtask(() async {
      try {
        Sprite? sprite;
        try {
          sprite = await game.loadSprite('leaderboard_background.png');
          debugPrint('CompetitionScreen: loaded leaderboard_background.png');
        } catch (_) {
          debugPrint(
            'CompetitionScreen: leaderboard_background.png not found, trying background.png',
          );
          try {
            sprite = await game.loadSprite('background.png');
            debugPrint('CompetitionScreen: loaded background.png');
          } catch (_) {
            sprite = null;
          }
        }

        if (sprite != null) {
          final bg = SpriteComponent()
            ..sprite = sprite
            ..size = game.size
            ..position = Vector2.zero();
          add(bg);
          debugPrint('CompetitionScreen: background sprite added');
          // Remove the loading placeholder once we've added the real bg
          try {
            loadingPlaceholder.removeFromParent();
          } catch (_) {}
          // Remove the Flutter fallback overlay if it's present
          try {
            final g = findGame();
            if (g != null) g.overlays.remove('competition_fallback');
          } catch (_) {}
        }
      } catch (_) {}
    });

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
      try {
        loadingPlaceholder.removeFromParent();
      } catch (_) {}
      // Show retry UI handled here
      return;
    }

    await _showLeaderboardUI();
  }

  Future<void> _showLeaderboardUI() async {
    leaderboardEntries = await _fetchTopPlayers(8);
    // Cache leaderboard entries locally
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'cached_leaderboard',
        jsonEncode(leaderboardEntries),
      );
    } catch (_) {}
    try {
      if (_cachedLeaderboardContainer != null) {
        try {
          _cachedLeaderboardContainer!.removeFromParent();
        } catch (_) {}
        _cachedLeaderboardContainer = null;
      }
    } catch (_) {}

    try {
      loadingPlaceholder.removeFromParent();
    } catch (_) {}

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
    final buttonWidth = 250.0;
    final buttonHeight = 60.0;
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
      // Override league from local storage if available
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
            // Allow guest users to join immediately without forcing authentication.
            final user = await svc.waitForSignIn(
              timeout: const Duration(seconds: 3),
            );
            try {
              final prefs = await SharedPreferences.getInstance();

              if (user == null) {
                // Guest user path
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
                // Non-blocking server call to join tournament as guest.
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

              // Signed-in user path
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
              // Ensure navigation to tournament UI; server sync may be retried later.
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
                //
                try {
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setBool('pendingTournamentAutoSearch', true);
                } catch (_) {}
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
    // Fast local mode: return a static dummy leaderboard immediately and
    // skip any network calls. This is intentional for quick local testing.
    if (forceDummyLeaderboard) {
      final currentUid = fb.FirebaseAuth.instance.currentUser?.uid ?? '';
      final names = [
        'Alex',
        'Chris',
        'Jordan',
        'Taylor',
        'Sam',
        'Riley',
        'Morgan',
        'Pat',
      ];
      final List<Map<String, dynamic>> dummy = List.generate(limit, (i) {
        final score = (limit - i) * 100; // descending scores
        return {
          'playerId': 'dummy_$i',
          'name': names[i % names.length],
          'score': score,
        };
      });
      if (currentUid.isNotEmpty) {
        // Place the current user in the list as "You" (last slot)
        final youIndex = (limit - 1).clamp(0, limit - 1);
        dummy[youIndex] = {'playerId': currentUid, 'name': 'You', 'score': 0};
      }
      return dummy;
    }
    try {
      final HttpsCallable callable = functions.httpsCallable('getLeaderboard');
      final result = await callable.call({'limit': limit});
      final Map<String, dynamic> payload =
          result.data as Map<String, dynamic>? ?? {};
      final List<dynamic> list = payload['leaderboard'] as List<dynamic>? ?? [];

      // Determine current user id so we can mark the local user as "You".
      // Also support guest ids stored locally so guest players see themselves.
      String currentUid = fb.FirebaseAuth.instance.currentUser?.uid ?? '';
      try {
        final prefs = await SharedPreferences.getInstance();
        final guest = prefs.getString('guest_id') ?? '';
        if (currentUid.isEmpty && guest.isNotEmpty) currentUid = guest;
      } catch (_) {}

      final mapped = list.map((e) {
        try {
          final playerId = e['playerId'] ?? e['rawId'] ?? '';
          final name = e['name'] ?? 'Player';
          final score = (e['score'] is num)
              ? (e['score'] as num).toInt()
              : int.tryParse('${e['score']}') ?? 0;
          return {'playerId': playerId, 'name': name, 'score': score};
        } catch (_) {
          return {'playerId': '', 'name': 'Player', 'score': 0};
        }
      }).toList();

      // If the current user appears in the returned list, replace their
      // visible name with "You" so the player can easily find themselves.
      bool foundCurrent = false;
      if (currentUid.isNotEmpty) {
        for (final item in mapped) {
          if (item['playerId'] == currentUid) {
            item['name'] = 'You';
            foundCurrent = true;
          }
        }
      }

      // If the current user isn't in the top list, fetch and use their entry as 'You'.
      if (!foundCurrent && currentUid.isNotEmpty) {
        try {
          final svc = CompetitionService();
          final weekId = svc.getCurrentWeekId();
          final entry = await svc.getUserEntry(weekId, currentUid);
          if (entry != null) {
            mapped.add({
              'playerId': currentUid,
              'name': 'You',
              'score': entry.xp,
            });
          } else {
            // As a last resort, show a placeholder You row with zero XP
            mapped.add({'playerId': currentUid, 'name': 'You', 'score': 0});
          }
        } catch (_) {
          mapped.add({'playerId': currentUid, 'name': 'You', 'score': 0});
        }
      }

      return mapped.cast<Map<String, dynamic>>();
    } catch (_) {
      return [];
    }
  }
}
