import 'dart:convert';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter/foundation.dart' show debugPrint;
import '../models/score.dart';

class ScoreService {
  // Save a score. If user is logged in, push to Firebase, if not, store locally on the user's device
  Future<void> saveScore(Score score, {bool loggedIn = false}) async {
    if (loggedIn) {
      // Logged-in user, push to Firebase
      try {
        // Ensure token is fresh before calling server
        try {
          final user = fb.FirebaseAuth.instance.currentUser;
          if (user != null) {
            await user.getIdToken(true);
            try {
              await fb.FirebaseAuth.instance
                  .idTokenChanges()
                  .firstWhere((u) => u?.uid == user.uid)
                  .timeout(const Duration(seconds: 2));
            } catch (_) {}
          }
        } catch (e) {
          debugPrint('Token refresh failed before saveScore: $e');
        }
        final callable = FirebaseFunctions.instanceFor(
          region: 'us-central1',
        ).httpsCallable('updateScore');
        final result = await callable.call({
          'playerId': score.playerId,
          'result': _scoreResult(score),
        });
        debugPrint('Score updated successfully: ${result.data}');
      } catch (e) {
        debugPrint('Error saving score to Firebase: $e');
      }
    } else {
      // Guest user save locally in SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final key = 'guest_score_${score.playerId}';

      List<Map<String, dynamic>> scores = [];
      final saved = prefs.getString(key);
      if (saved != null) {
        scores = List<Map<String, dynamic>>.from(json.decode(saved));
      }

      scores.add({
        'wins': score.wins,
        'draws': score.draws,
        'losses': score.losses,
        'points': score.points,
        'timestamp': DateTime.now().toIso8601String(),
      });

      await prefs.setString(key, json.encode(scores));
      debugPrint('Guest score saved locally: $scores');
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

  // Save and add sscores after sign in
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
    debugPrint(
      'All guest scores moved to Firebase and local storage info cleared.',
    );
  }

  String _scoreResult(Score score) {
    if (score.wins > 0) return 'win';
    if (score.draws > 0) return 'draw';
    return 'loss';
  }
}
