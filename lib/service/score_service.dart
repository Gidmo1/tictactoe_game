import 'dart:convert';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter/foundation.dart' show debugPrint;
import '../models/score.dart';
import 'local_db.dart';

class ScoreService {
  // Save a score: send to server when logged in, otherwise cache locally.
  Future<void> saveScore(Score score, {bool loggedIn = false}) async {
    // Determine effective player id: prefer authenticated uid or fallback to score.playerId.
    final currentUser = fb.FirebaseAuth.instance.currentUser;
    final effectivePlayerId = currentUser?.uid ?? score.playerId;
    final willBeLoggedIn = currentUser != null;

    try {
      // If the caller will be authenticated, refresh token to provide a
      // fresh auth context to the callable.
      if (willBeLoggedIn) {
        try {
          final user = currentUser;
          await user.getIdToken(true);
          try {
            await fb.FirebaseAuth.instance
                .idTokenChanges()
                .firstWhere((u) => u?.uid == user.uid)
                .timeout(const Duration(seconds: 2));
          } catch (_) {}
        } catch (e) {
          debugPrint('Token refresh failed before saveScore $e');
        }
      }

      final callable = FirebaseFunctions.instanceFor(
        region: 'us-central1',
      ).httpsCallable('updateScore');
      final result = await callable.call({
        'playerId': effectivePlayerId,
        'result': _scoreResult(score),
      });
      debugPrint('Score updated successfully: ${result.data}');

      // Remove any local cache for the original score.playerId (guest) if present
      try {
        final prefs = await SharedPreferences.getInstance();
        final guestKey = 'guest_score_${score.playerId}';
        if (prefs.containsKey(guestKey)) await prefs.remove(guestKey);
      } catch (_) {}

      return;
    } catch (e) {
      debugPrint('Error saving score to Firebase (will cache locally): $e');
    }

    // Fallback: persist guest score locally under guest_score_<playerId> for retry.
    try {
      // Persist to local SQLite as a robust cache
      final db = LocalDb.instance;
      await db.init();
      await db.saveGuestScore(score.playerId, {
        'wins': score.wins,
        'draws': score.draws,
        'losses': score.losses,
        'points': score.points,
        'timestamp': DateTime.now().toIso8601String(),
      });
      debugPrint('Guest score saved to local DB for ${score.playerId}');
    } catch (e) {
      debugPrint('Failed to persist guest score locally: $e');
    }
  }

  // Submit a tournament match result to the server (authoritative; no local cache).
  Future<void> submitTournamentResult({
    required String tournamentId,
    required String matchId,
    required String winnerId,
  }) async {
    try {
      final callable = FirebaseFunctions.instanceFor(
        region: 'us-central1',
      ).httpsCallable('submitTournamentResult');
      await callable.call({
        'tournamentId': tournamentId,
        'matchId': matchId,
        'winnerId': winnerId,
      });
      debugPrint('Tournament result submitted for $matchId');
    } catch (e) {
      debugPrint('Failed to submit tournament result: $e');
    }
  }

  // Submit a competition (weekly leaderboard) score update via callable.
  Future<void> submitCompetitionScore({
    required String playerId,
    required String result,
  }) async {
    try {
      final callable = FirebaseFunctions.instanceFor(
        region: 'us-central1',
      ).httpsCallable('updateCompetitionScore');
      await callable.call({'playerId': playerId, 'result': result});
      debugPrint('Competition score updated for $playerId ($result)');
    } catch (e) {
      debugPrint('Failed to update competition score: $e');
    }
  }

  // Upload any locally cached guest scores (guest_score_<id>) to the server.
  Future<void> uploadAllGuestCaches() async {
    // Read cached guest scores from local SQLite and upload them.
    try {
      final db = LocalDb.instance;
      await db.init();
      final rows = await db.getAllGuestScores();
      // Group by player_id
      final grouped = <String, List<Map<String, dynamic>>>{};
      for (final r in rows) {
        final pid = r['player_id'] as String? ?? '';
        grouped.putIfAbsent(pid, () => []).add(r);
      }
      for (final entry in grouped.entries) {
        final playerId = entry.key;
        final list = entry.value;
        for (final s in list) {
          try {
            final score = Score(
              playerId: playerId,
              playerName: s['playerName'] ?? 'Guest',
              wins: s['wins'] ?? 0,
              draws: s['draws'] ?? 0,
              losses: s['losses'] ?? 0,
              points: s['points'] ?? 0,
            );
            await saveScore(score, loggedIn: false);
          } catch (e) {
            debugPrint('Failed to upload cached row for $playerId: $e');
          }
        }
        // Clean up rows for this player after attempting upload
        try {
          await db.deleteGuestScoresFor(playerId);
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('Upload guest caches failed: $e');
    }
  }

  // Retrieve scores for a user
  Future<List<Score>> getScores(
    String playerId, {
    bool loggedIn = false,
  }) async {
    if (loggedIn) {
      try {
        final callable = FirebaseFunctions.instanceFor(
          region: 'us-central1',
        ).httpsCallable('getScore');
        final result = await callable.call({'playerId': playerId});
        final data = result.data as Map<String, dynamic>;
        return [Score.fromJson(data)];
      } catch (e) {
        debugPrint('Error fetching score: $e');
        return [];
      }
    } else {
      final prefs = await SharedPreferences.getInstance();
      final key = 'guest_score_$playerId';
      final saved = prefs.getString(key);
      if (saved != null) {
        final list = List<Map<String, dynamic>>.from(json.decode(saved));
        return list.map((e) => Score.fromJson(e)).toList();
      }
      return [];
    }
  }

  // Sync guest scores to the server after sign in
  Future<void> syncGuestScores(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs
        .getKeys()
        .where((k) => k.startsWith('guest_score_'))
        .toList();

    for (var key in keys) {
      final saved = prefs.getString(key);
      if (saved != null) {
        final scores = List<Map<String, dynamic>>.from(json.decode(saved));
        for (var s in scores) {
          final score = Score(
            playerId: userId,
            playerName: s['playerName'] ?? 'Guest',
            wins: s['wins'] ?? 0,
            draws: s['draws'] ?? 0,
            losses: s['losses'] ?? 0,
            points: s['points'] ?? 0,
          );
          await saveScore(score, loggedIn: true);
        }
      }
      await prefs.remove(key);
    }
    debugPrint('Guest scores synced to Firebase; local cache cleared.');
  }

  String _scoreResult(Score score) {
    if (score.wins > 0) return 'win';
    if (score.draws > 0) return 'draw';
    return 'loss';
  }
}
