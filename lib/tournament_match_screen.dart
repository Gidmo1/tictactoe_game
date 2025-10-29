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
  Component? _searchControl; // Play or Cancel button reference

  @override
  Future<void> onLoad() async {
    final canvasSize = findGame()?.size ?? Vector2(360, 640);

    // Detect if this view was opened by a user who already joined the
    // tournament. If the Competition screen requested matchmaking,
    // then the game will start auto searcg
    final flameGame = findGame();
    final bool joinedView =
        flameGame != null &&
        ((flameGame as dynamic).pendingTournamentJoinView == true);
    final bool autoSearchFlag =
        flameGame != null &&
        ((flameGame as dynamic).pendingTournamentAutoSearch == true);

    bool prefsAutoSearch = false;
    try {
      final prefs = await SharedPreferences.getInstance();
      prefsAutoSearch = prefs.getBool('pendingTournamentAutoSearch') ?? false;
      if (prefsAutoSearch) {
        // Clear it immediately
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

    // Center Play button. If Search is
    // requested we hide the button and begin matchmaking immediately
    if (!joinedView && !autoSearch) {
      final playButton = PlayButton(
        imagePath: 'play.png',
        position: canvasSize / 2,
        size: Vector2(180, 80),
        onPressed: _startMatchmaking,
      );
      _searchControl = playButton;
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
    // Cancel matchmaking when the user navigates away to avoid leaving
    // stale queue entries on the server.
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

    // While searching, swap the Play button to a Cancel button.
    _showCancelControl();

    try {
      while (_isSearching && !_isRemoved) {
        try {
          final data = await svc.matchmakeForTournament(
            weekId: tournamentId,
            userId: userId,
            userName: user?.displayName ?? 'Guest',
          );

          debugPrint('matchmakeForTournament result: $data');

          final Map<String, dynamic> dataMap = Map<String, dynamic>.from(data);
          final status = dataMap['status'] as String? ?? 'unknown';

          if (status == 'waiting' || status == 'already_in_queue') {
            statusText?.text = 'Waiting for an opponent...';
            await Future.delayed(const Duration(seconds: 2));
            continue;
          }

          if (status == 'matched') {
            final matchId = dataMap['matchId'] as String?;
            final flameGame = findGame();
            if (flameGame != null && matchId != null) {
              final g = (flameGame as dynamic);
              g.pendingMatchId = matchId;
              g.pendingMatchIsTournament = true;
              if (dataMap.containsKey('youAre') &&
                  dataMap['youAre'] is String) {
                final raw = (dataMap['youAre'] as String).trim();
                if (raw.toLowerCase().contains('o'))
                  g.myPlayerSymbol = 'O';
                else
                  g.myPlayerSymbol = 'X';
              } else {
                g.myPlayerSymbol = 'X';
              }
              // Navigate to match screen
              _isSearching = false;
              _restorePlayControl();
              g.router.pushNamed('invite');
              return;
            }
          }

          statusText?.text = 'Unknown status: $status';
          break;
        } catch (e) {
          if (!_isRemoved) {
            statusText?.text = 'Matchmaking error. Retrying...';
            debugPrint('Matchmaking error: $e');
            await Future.delayed(const Duration(seconds: 2));
            continue;
          }
        }
      }
    } finally {
      _isSearching = false;
      _restorePlayControl();
    }
  }

  // Public entrypoint so external controllers can trigger matchmaking.
  void startMatchmaking() {
    debugPrint(
      'TournamentMatchScreen.startMatchmaking invoked ts=${DateTime.now().toIso8601String()} _isSearching=$_isSearching',
    );
    // Schedule start; the private method prevents duplicate work.
    Future.microtask(() => _startMatchmaking());
  }

  Future<void> _cancelMatchmaking() async {
    if (!_isSearching) return;
    // Update UI immediately before the network call.
    _isSearching = false;
    statusText?.text = 'Tap Play to find an opponent';
    _restorePlayControl();

    final fbUser = FirebaseAuth.instance.currentUser;
    final userId =
        fbUser?.uid ?? 'guest_${DateTime.now().millisecondsSinceEpoch}';
    final tournamentId =
        'weekly_${DateTime.now().year}-W${_currentWeekNumber()}';
    try {
      await _leaveQueue(userId, tournamentId);
    } catch (e) {
      debugPrint('Error while leaving queue: $e');
    }
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

  // Swap the on-screen Play button to a Cancel button while searching.
  void _showCancelControl() {
    try {
      final flameGame = findGame();
      final pos = flameGame?.size != null ? flameGame!.size / 2 : Vector2(0, 0);
      try {
        _searchControl?.removeFromParent();
      } catch (_) {}

      final cancelBtn = PlayButton(
        imagePath: 'cancel.png',
        position: pos,
        size: Vector2(180, 80),
        onPressed: _cancelMatchmaking,
      );
      _searchControl = cancelBtn;
      add(cancelBtn);
    } catch (_) {}
  }

  // Restore the Play button in place of the Cancel button.
  void _restorePlayControl() {
    try {
      final flameGame = findGame();
      final pos = flameGame?.size != null ? flameGame!.size / 2 : Vector2(0, 0);
      try {
        _searchControl?.removeFromParent();
      } catch (_) {}

      final playBtn = PlayButton(
        imagePath: 'play.png',
        position: pos,
        size: Vector2(180, 80),
        onPressed: _startMatchmaking,
      );
      _searchControl = playBtn;
      add(playBtn);
      // Update status text to the normal state when Play is restored.
      statusText?.text = 'Tap Play to find an opponent';
    } catch (_) {}
  }
}

//  BUTTON CLASSES
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
