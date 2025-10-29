import 'dart:async';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/effects.dart';
import 'package:flame_audio/flame_audio.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'service/competition_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:tictactoe_game/settings_screen.dart';

class TournamentMatchScreen extends Component {
  TextComponent? statusText;
  bool _isSearching = false; // Track matchmaking state
  bool _isRemoved = false; // Track if component is removed

  @override
  Future<void> onLoad() async {
    final canvasSize = findGame()?.size ?? Vector2(360, 640);

    // Detect if this view was opened by a user who already joined the
    // tournament. If the Competition screen requested matchmaking,
    // we'll auto-start the search.
    final flameGame = findGame();
    final bool joinedView =
        flameGame != null &&
        ((flameGame as dynamic).pendingTournamentJoinView == true);
    final bool autoSearchFlag =
        flameGame != null &&
        ((flameGame as dynamic).pendingTournamentAutoSearch == true);

    // Also consult the short-lived SharedPreferences flag set by the
    // Competition screen as a more reliable signal across navigation.
    bool prefsAutoSearch = false;
    try {
      final prefs = await SharedPreferences.getInstance();
      prefsAutoSearch = prefs.getBool('pendingTournamentAutoSearch') ?? false;
      if (prefsAutoSearch) {
        // Clear it immediately so it does not persist across later visits.
        await prefs.remove('pendingTournamentAutoSearch');
      }
    } catch (_) {}

    final bool autoSearch = autoSearchFlag || prefsAutoSearch;

    // Clear the join-flag so re-entering behaves normally.
    if (joinedView) {
      try {
        (flameGame as dynamic).pendingTournamentJoinView = false;
      } catch (_) {}
    }
    // Clear the auto-search flag and schedule matchmaking if requested.
    if (autoSearch) {
      try {
        (flameGame as dynamic).pendingTournamentAutoSearch = false;
      } catch (_) {}
    }

    // Background
    final background = SpriteComponent()
      ..sprite = await Sprite.load('background.png')
      ..size = canvasSize
      ..position = Vector2.zero();
    add(background);

    // Return button
    final returnButton = ReturnButton(
      imagePath: 'return.png',
      position: Vector2(40, 60),
      size: Vector2(50, 50),
      onPressed: () {
        final flameGame = findGame();
        if (flameGame != null) {
          final router = (flameGame as dynamic).router;
          router?.pushNamed('competition');
        }
      },
    );
    add(returnButton);

    // Center Play button (hidden if this is the informational view for a
    // returning player who already joined the tournament). If autoSearch is
    // requested we hide the button and begin matchmaking immediately.
    if (!joinedView && !autoSearch) {
      final playButton = PlayButton(
        imagePath: 'play.png',
        position: canvasSize / 2,
        size: Vector2(180, 80),
        onPressed: _startMatchmaking,
      );
      add(playButton);
    }

    // Status text
    statusText = TextComponent(
      text: autoSearch
          ? 'Searching for opponent...'
          : (joinedView
                ? 'You have already joined the tournament. Waiting for opponents or press Return.'
                : 'Tap Play to find an opponent'),
      position: Vector2(canvasSize.x / 2, canvasSize.y / 2 - 80),
      anchor: Anchor.center,
      textRenderer: TextPaint(
        style: const TextStyle(color: Colors.white, fontSize: 18),
      ),
    );
    add(statusText!);

    // If the Competition screen asked us to auto-start matchmaking, do that
    // now after the UI is in place.
    if (autoSearch) {
      // Schedule start; _startMatchmaking prevents duplicate calls.
      Future.microtask(() => _startMatchmaking());
    }
  }

  @override
  void onRemove() {
    super.onRemove();
    _isRemoved = true; // Mark as removed
    _cancelMatchmaking();
    statusText?.text = 'Tap Play to find an opponent'; // reset status
  }

  Future<void> _startMatchmaking() async {
    debugPrint(
      'TournamentMatchScreen._startMatchmaking: entry _isSearching=$_isSearching ts=${DateTime.now().toIso8601String()}',
    );
    if (_isSearching) return; // prevent double call
    _isSearching = true;
    statusText?.text = 'Searching for opponent...';

    final svc = CompetitionService();
    final user = await svc.waitForSignIn();
    final userId =
        user?.uid ?? 'guest_${DateTime.now().millisecondsSinceEpoch}';
    final tournamentId =
        'weekly_${DateTime.now().year}-W${_currentWeekNumber()}';

    try {
      final data = await svc.matchmakeForTournament(
        weekId: tournamentId,
        userId: userId,
        userName: user?.displayName ?? 'Guest',
      );

      if (_isRemoved) {
        // User left the screen, cancel anything
        await _leaveQueue(userId, tournamentId);
        return;
      }

      // Log response and update the status text.
      try {
        debugPrint('matchmakeForTournament result: $data');
        statusText?.text = 'Matchmaking response: ${data.toString()}';
      } catch (_) {}

      // `data` is expected to be a map from the matchmaker callable.
      final Map<String, dynamic> dataMap = Map<String, dynamic>.from(data);
      final status = dataMap['status'] as String? ?? 'unknown';
      if (status == 'waiting') {
        statusText?.text = 'Waiting for an opponent...';
      } else if (status == 'matched') {
        final matchId = dataMap['matchId'] as String?;

        final flameGame = findGame();
        if (flameGame != null && matchId != null) {
          final g = (flameGame as dynamic);
          g.pendingMatchId = matchId;
          g.pendingMatchIsTournament = true;
          // If server tells us which side we are, use it; otherwise assume X
          if (dataMap.containsKey('youAre') && dataMap['youAre'] is String) {
            final raw = (dataMap['youAre'] as String).trim();
            // Accept either 'playerO'/'playerX' (server) or legacy 'O'/'X'
            if (raw == 'playerO' ||
                raw == 'youareplayerO' ||
                raw == 'playero' ||
                raw.toLowerCase() == 'youareplayero') {
              g.myPlayerSymbol = 'O';
            } else if (raw == 'playerX' ||
                raw == 'youareplayerX' ||
                raw == 'playerx' ||
                raw.toLowerCase() == 'youareplayerx') {
              g.myPlayerSymbol = 'X';
            } else if (raw == 'O' || raw == 'X') {
              g.myPlayerSymbol = raw;
            } else {
              // Fallback: take last char if it's X or O
              final last = raw.isNotEmpty ? raw.characters.last : 'X';
              g.myPlayerSymbol = (last == 'O' || last == 'X') ? last : 'X';
            }
          } else {
            g.myPlayerSymbol = 'X';
          }
          g.router.pushNamed('invite');
        }
      } else if (status == 'already_in_queue') {
        statusText?.text = 'You are already in the queue. Waiting...';
      } else {
        statusText?.text = 'Unknown status: $status';
      }
    } catch (e) {
      if (!_isRemoved) {
        statusText?.text = 'Matchmaking failed. Try again.';
        debugPrint('Matchmaking error: $e');
      }
    } finally {
      _isSearching = false;
    }
  }

  /// Public entrypoint so external controllers can trigger matchmaking.
  void startMatchmaking() {
    debugPrint(
      'TournamentMatchScreen.startMatchmaking invoked ts=${DateTime.now().toIso8601String()} _isSearching=$_isSearching',
    );
    // Schedule start; the private method prevents duplicate work.
    Future.microtask(() => _startMatchmaking());
  }

  Future<void> _cancelMatchmaking() async {
    if (!_isSearching) return;
    final fbUser = FirebaseAuth.instance.currentUser;
    final userId =
        fbUser?.uid ?? 'guest_${DateTime.now().millisecondsSinceEpoch}';
    final tournamentId =
        'weekly_${DateTime.now().year}-W${_currentWeekNumber()}';
    await _leaveQueue(userId, tournamentId);
    _isSearching = false;
  }

  Future<void> _leaveQueue(String playerId, String tournamentId) async {
    try {
      final callable = FirebaseFunctions.instanceFor(region: 'us-central1')
          .httpsCallable(
            'leaveTournamentQueue', // you implement
          );
      await callable.call({'playerId': playerId, 'tournamentId': tournamentId});
      debugPrint('Left tournament queue.');
    } catch (e) {
      debugPrint('Error leaving tournament queue: $e');
    }
  }

  int _currentWeekNumber() {
    final now = DateTime.now();
    final startOfYear = DateTime(now.year, 1, 1);
    final daysPassed = now.difference(startOfYear).inDays + 1;
    return ((daysPassed + startOfYear.weekday) / 7).ceil();
  }
}

// --- BUTTON CLASSES ---
class ReturnButton extends SpriteComponent with TapCallbacks {
  final FutureOr<void> Function() onPressed;
  final String imagePath;

  ReturnButton({
    required this.imagePath,
    required Vector2 position,
    required Vector2 size,
    required this.onPressed,
  }) : super(position: position, size: size, anchor: Anchor.center);

  @override
  Future<void> onLoad() async {
    sprite = await Sprite.load(imagePath);
  }

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

    Future.delayed(const Duration(milliseconds: 150), () => onPressed());
  }
}

class PlayButton extends SpriteComponent with TapCallbacks {
  final FutureOr<void> Function() onPressed;
  final String imagePath;

  PlayButton({
    required this.imagePath,
    required Vector2 position,
    required Vector2 size,
    required this.onPressed,
  }) : super(position: position, size: size, anchor: Anchor.center);

  @override
  Future<void> onLoad() async {
    sprite = await Sprite.load(imagePath);
  }

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

    Future.delayed(const Duration(milliseconds: 150), () => onPressed());
  }
}
