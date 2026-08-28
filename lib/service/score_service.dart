import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'supabase_compat.dart';
import '../models/score.dart';
import 'local_db.dart';

class ScoreService {
  // Save a score: send to server when logged in, otherwise cache locally.
  Future<bool> saveScore(
    Score score, {
    bool loggedIn = false,
    int boardSize = 3,
    String opponentType = 'computer',
    bool updateLocalTotals = true,
  }) async {
    // Determine effective player id: prefer authenticated uid or fallback to score.playerId.
    final currentUser = Supabase.instance.client.auth.currentUser;
    final effectivePlayerId = currentUser?.id ?? score.playerId;
    final willBeLoggedIn = currentUser != null;

    try {
      if (!willBeLoggedIn) throw StateError('No authenticated Supabase user');
      await Supabase.instance.client.rpc(
        'record_score',
        params: {
          'score_result': _scoreResult(score),
          'score_points': score.points,
          'score_board_size': boardSize,
          'score_opponent_type': opponentType,
        },
      );
      debugPrint('Score saved to Supabase for $effectivePlayerId');

      // Remove any local cache for the original score.playerId (guest) if present
      try {
        final prefs = await SharedPreferences.getInstance();
        final guestKey = 'guest_score_${score.playerId}';
        if (prefs.containsKey(guestKey)) await prefs.remove(guestKey);
      } catch (_) {}

      return true;
    } catch (e) {
      debugPrint('Error saving score to Supabase (will cache locally): $e');
      if (updateLocalTotals) {
        await recordOfflineMatch(_scoreResult(score));
      }
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
      return false;
    } catch (e) {
      debugPrint('Failed to persist guest score locally: $e');
      return false;
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
        var migrated = true;
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
            final saved = await saveScore(
              score,
              loggedIn: true,
              updateLocalTotals: false,
            );
            migrated = migrated && saved;
          } catch (e) {
            debugPrint('Failed to upload cached row for $playerId: $e');
            migrated = false;
          }
        }
        if (migrated) await db.deleteGuestScoresFor(playerId);
      }

      final prefs = await SharedPreferences.getInstance();
      final legacyKeys = prefs
          .getKeys()
          .where((key) => key.startsWith('guest_score_'))
          .toList();
      for (final key in legacyKeys) {
        final raw = prefs.getString(key);
        if (raw == null) continue;
        var migrated = true;
        try {
          final cached = List<Map<String, dynamic>>.from(json.decode(raw));
          for (final data in cached) {
            final saved = await saveScore(
              Score(
                playerId: key.substring('guest_score_'.length),
                playerName: data['playerName'] ?? 'Guest',
                wins: data['wins'] ?? 0,
                draws: data['draws'] ?? 0,
                losses: data['losses'] ?? 0,
                points: data['points'] ?? 0,
              ),
              loggedIn: true,
            );
            migrated = migrated && saved;
          }
          if (migrated) await prefs.remove(key);
        } catch (e) {
          debugPrint('Failed to migrate legacy guest cache $key: $e');
        }
      }
    } catch (e) {
      debugPrint('Upload guest caches failed: $e');
    }
  }

  Future<void> recordOfflineMatch(String result) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(
      'offline_wins',
      (prefs.getInt('offline_wins') ?? 0) + (result == 'win' ? 1 : 0),
    );
    await prefs.setInt(
      'offline_losses',
      (prefs.getInt('offline_losses') ?? 0) + (result == 'loss' ? 1 : 0),
    );
    await prefs.setInt(
      'offline_draws',
      (prefs.getInt('offline_draws') ?? 0) + (result == 'draw' ? 1 : 0),
    );
  }

  Future<bool> migrateForFirstAccountSignIn(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'supabase_account_seen_$userId';
    if (prefs.getBool(key) ?? false) return false;

    await uploadAllGuestCaches();
    await prefs.setBool(key, true);
    return true;
  }

  Future<void> markAccountAsKnown(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('supabase_account_seen_$userId', true);
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
          await saveScore(
            score,
            loggedIn: true,
            updateLocalTotals: false,
          );
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
