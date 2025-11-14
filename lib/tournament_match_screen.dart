import 'dart:math';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:tictactoe_game/settings_screen.dart';
import 'service/competition_service.dart';

class TournamentMatchScreen extends Component {
  TextComponent? statusText;
  bool _isSearching = false;
  bool _isRemoved = false;
  TextComponent? detailText;
  int _attempts = 0;
  String _lastError = '';

  @override
  Future<void> onLoad() async {
    final canvasSize = findGame()?.size ?? Vector2(360, 640);

    // Handle Competition to Tournament auto-search flag
    final flameGame = findGame();
    final bool inMemoryAuto =
        flameGame != null &&
        ((flameGame as dynamic).pendingTournamentAutoSearch == true);

    bool prefsAuto = false;
    try {
      final prefs = await SharedPreferences.getInstance();
      prefsAuto = prefs.getBool('pendingTournamentAutoSearch') ?? false;
      if (prefsAuto) await prefs.remove('pendingTournamentAutoSearch');
    } catch (_) {}

    final bool autoSearch = inMemoryAuto || prefsAuto;

    // Clear the in-memory flag so re-entering behaves normally.
    if (inMemoryAuto) {
      try {
        (flameGame as dynamic).pendingTournamentAutoSearch = false;
      } catch (_) {}
    }

    // Background
    final background = SpriteComponent()
      ..sprite =
          await (findGame()?.loadSprite('background.png') ??
              Sprite.load('background.png'))
      ..size = canvasSize
      ..position = Vector2.zero();
    add(background);

    // If autoSearch requested, the screen stays in searching state until matched or exit.
    // Status text
    statusText = TextComponent(
      text: autoSearch
          ? 'Waiting for player to join...'
          : 'Waiting for player to join...',
      position: Vector2(canvasSize.x / 2, canvasSize.y / 2),
      anchor: Anchor.center,
      textRenderer: TextPaint(
        style: const TextStyle(color: Colors.white, fontSize: 20),
      ),
    );
    add(statusText!);

    // Small detail text for debug or info
    detailText = TextComponent(
      text: '',
      position: Vector2(canvasSize.x / 2, canvasSize.y / 2 + 32),
      anchor: Anchor.center,
      textRenderer: TextPaint(
        style: const TextStyle(color: Colors.white70, fontSize: 12),
      ),
    );
    add(detailText!);

    // If autoSearch requested, begin matchmaking when UI is ready.
    if (autoSearch) {
      Future.microtask(() => _startMatchmakingLocked());
      // Force-bot UI removed; AI fallback disabled for matchmaking.
    }

    return Future.value();
  }

  @override
  void onRemove() {
    super.onRemove();
    _isRemoved = true;
    // Cancel matchmaking to ensure we don't leave stale queue entries.
    _cancelMatchmaking();
    statusText?.text = 'Waiting for opponent...';
  }

  Future<void> _startMatchmakingLocked() async {
    if (_isSearching || _isRemoved) return;
    _isSearching = true;
    statusText?.text = 'Searching for opponent...';

    final svc = CompetitionService();
    final user = await svc.waitForSignIn();
    final userId =
        user?.uid ?? 'guest_${DateTime.now().millisecondsSinceEpoch}';
    final tournamentId = svc.getCurrentWeekId();

    try {
      // Randomized fallback threshold for AI matchmaking (5–6s).
      final fallbackSeconds = 5 + Random().nextInt(2); // 5..6 seconds
      final startTime = DateTime.now();

      while (_isSearching && !_isRemoved) {
        _attempts++;
        try {
          detailText?.text = '';
          final data = await svc.matchmakeForTournament(
            weekId: tournamentId,
            userId: userId,
            userName: user?.displayName ?? 'Guest',
          );

          final Map<String, dynamic> dataMap = Map<String, dynamic>.from(data);
          final status = dataMap['status'] as String? ?? 'unknown';

          if (status == 'waiting' || status == 'already_in_queue') {
            statusText?.text = 'Waiting for an opponent...';

            // Wait briefly and check elapsed time before considering fallback.
            await Future.delayed(const Duration(seconds: 1));
            final elapsed = DateTime.now().difference(startTime).inSeconds;

            if (elapsed >= fallbackSeconds) {
              // AI fallback disabled: continue searching for human opponents.
              detailText?.text = 'Still searching for human opponents...';
              // Small backoff before the next matchmaking attempt to avoid tight loop
              await Future.delayed(const Duration(seconds: 1));
              continue;
            }

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
              g.router.pushNamed('invite');
              return;
            }
          }

          statusText?.text = 'Unknown status: $status';
          break;
        } catch (e) {
          if (!_isRemoved) {
            _lastError = e.toString();
            statusText?.text = 'Matchmaking error. Retrying...';
            /*detailText?.text =
                'Attempts: $_attempts • Last error: ${_lastError.length > 120 ? _lastError.substring(0, 120) + '...' : _lastError}';
            debugPrint('Matchmaking error: $e');*/
            // Wait a little before retrying; if the randomized fallback
            // time has elapsed, attempt the AI creation as a fallback.
            await Future.delayed(const Duration(seconds: 2));
            final elapsed = DateTime.now().difference(startTime).inSeconds;
            if (elapsed >= fallbackSeconds) {
              // AI fallback disabled — do nothing special; continue retrying matchmaking.
              await Future.delayed(const Duration(seconds: 1));
            }
            continue;
          }
        }
      }
    } finally {
      _isSearching = false;
    }
  }

  // Public entry point to start locked matchmaking (used by route handler).
  Future<void> startMatchmaking() async {
    await _startMatchmakingLocked();
  }

  Future<void> _cancelMatchmaking() async {
    if (!_isSearching) return;
    _isSearching = false;
    statusText?.text = 'Waiting for opponent';

    final fbUser = FirebaseAuth.instance.currentUser;
    final userId =
        fbUser?.uid ?? 'guest_${DateTime.now().millisecondsSinceEpoch}';
    final tournamentId = CompetitionService().getCurrentWeekId();
    try {
      await _leaveQueue(userId, tournamentId);
    } catch (e) {
      // debugPrint('Error while leaving queue: $e');
    }
  }

  Future<void> _leaveQueue(String playerId, String tournamentId) async {
    try {
      final callable = FirebaseFunctions.instanceFor(
        region: 'us-central1',
      ).httpsCallable('leaveTournamentQueue');
      await callable.call({'playerId': playerId, 'tournamentId': tournamentId});
      // debugPrint('Left tournament queue.');
    } catch (e) {
      // debugPrint('Error leaving tournament queue: $e');
    }
  }
}

// Simple button class just for UI
class ReturnButton extends SpriteComponent with TapCallbacks {
  final Future<void> Function() onPressed;
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
    return Future.value(); // <-- Fix null warning
  }

  @override
  void onTapDown(TapDownEvent event) {
    if (SettingsScreen.buttonSoundOn) {
      // Play sound here if needed
    }
    Future.delayed(const Duration(milliseconds: 100), () => onPressed());
  }
}
