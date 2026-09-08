import 'dart:math';
import 'package:tictactoe_game/models/tournament.dart';

/// Service for generating and managing tournament brackets
class BracketService {
  /// Generate a single-elimination bracket
  static Map<String, dynamic> generateSingleElimination(
    List<String> participants,
  ) {
    if (participants.isEmpty) return {};

    final bracket = <String, dynamic>{};
    final shuffled = List<String>.from(participants)..shuffle();

    // Round 1 matches
    final round1Matches = <Map<String, dynamic>>[];
    for (int i = 0; i < shuffled.length; i += 2) {
      final player1 = shuffled[i];
      final player2 = i + 1 < shuffled.length ? shuffled[i + 1] : null;

      round1Matches.add({
        'id': 'match_1_${i ~/ 2}',
        'round': 1,
        'position': i ~/ 2,
        'player1': player1,
        'player2': player2,
        'winner': null,
        'completed': false,
      });
    }

    bracket['round_1'] = round1Matches;

    // Calculate future rounds
    int currentRound = 1;
    int matchesInRound = round1Matches.length;

    while (matchesInRound > 1) {
      currentRound++;
      matchesInRound = (matchesInRound / 2).ceil();

      final nextRoundMatches = <Map<String, dynamic>>[];
      for (int i = 0; i < matchesInRound; i++) {
        nextRoundMatches.add({
          'id': 'match_${currentRound}_$i',
          'round': currentRound,
          'position': i,
          'player1': null,
          'player2': null,
          'winner': null,
          'completed': false,
        });
      }
      bracket['round_$currentRound'] = nextRoundMatches;
    }

    _advanceByes(bracket);

    return bracket;
  }

  static void _advanceByes(Map<String, dynamic> bracket) {
    var round = 1;
    while (bracket.containsKey('round_$round')) {
      final matches = bracket['round_$round'] as List;
      for (final match in matches) {
        if (match['completed'] == true ||
            match['player1'] == null ||
            match['player2'] != null) {
          continue;
        }
        final winner = match['player1'] as String;
        match['winner'] = winner;
        match['completed'] = true;
        final nextMatches = bracket['round_${round + 1}'];
        if (nextMatches is List && nextMatches.isNotEmpty) {
          final nextMatch = nextMatches[(match['position'] as int) ~/ 2];
          if ((match['position'] as int).isEven) {
            nextMatch['player1'] = winner;
          } else {
            nextMatch['player2'] = winner;
          }
        }
      }
      round++;
    }
  }

  /// Generate a round-robin bracket (everyone plays everyone once)
  static Map<String, dynamic> generateRoundRobin(
    List<String> participants,
  ) {
    final bracket = <String, dynamic>{};
    final matches = <Map<String, dynamic>>[];
    int matchId = 0;

    for (int i = 0; i < participants.length; i++) {
      for (int j = i + 1; j < participants.length; j++) {
        matches.add({
          'id': 'match_$matchId',
          'round': 1,
          'position': matchId,
          'player1': participants[i],
          'player2': participants[j],
          'winner': null,
          'completed': false,
        });
        matchId++;
      }
    }

    bracket['round_1'] = matches;
    return bracket;
  }

  /// Get all pending matches in a bracket
  static List<Map<String, dynamic>> getPendingMatches(
    Map<String, dynamic> bracket,
  ) {
    final pending = <Map<String, dynamic>>[];

    bracket.forEach((key, value) {
      if (key.startsWith('round_') && value is List) {
        for (final match in value) {
          if (match['completed'] != true &&
              match['player1'] != null &&
              match['player2'] != null) {
            pending.add(match);
          }
        }
      }
    });

    return pending;
  }

  /// Get next match for a participant in single elimination
  static Map<String, dynamic>? getNextMatchForParticipant(
    Map<String, dynamic> bracket,
    String participantUid,
  ) {
    final pending = getPendingMatches(bracket);
    for (final match in pending) {
      if (match['player1'] == participantUid || match['player2'] == participantUid) {
        return match;
      }
    }
    return null;
  }

  /// Complete a match and advance winner
  static bool completeMatch(
    Map<String, dynamic> bracket,
    String matchId,
    String winnerUid,
  ) {
    // Find the match
    Map<String, dynamic>? matchToComplete;
    String? matchRoundKey;

    bracket.forEach((key, value) {
      if (key.startsWith('round_') && value is List) {
        for (final match in value) {
          if (match['id'] == matchId) {
            matchToComplete = match;
            matchRoundKey = key;
          }
        }
      }
    });

    if (matchToComplete == null || matchRoundKey == null) return false;

    // Mark match as complete
    matchToComplete!['completed'] = true;
    matchToComplete!['winner'] = winnerUid;

    // Try to advance winner to next round
    final currentRound = matchToComplete!['round'] as int;
    final position = matchToComplete!['position'] as int;
    final nextRoundKey = 'round_${currentRound + 1}';

    if (bracket.containsKey(nextRoundKey)) {
      final nextRoundMatches = bracket[nextRoundKey] as List;
      final nextMatchPosition = position ~/ 2;
      if (nextMatchPosition < nextRoundMatches.length) {
        final nextMatch = nextRoundMatches[nextMatchPosition];

        // If it's player1's position, fill player1; otherwise player2
        if (position % 2 == 0) {
          nextMatch['player1'] = winnerUid;
        } else {
          nextMatch['player2'] = winnerUid;
        }
      }
    }

    return true;
  }

  /// Check if tournament is over (final match completed)
  static bool isTournamentOver(Map<String, dynamic> bracket) {
    // Find the final round
    int maxRound = 0;
    bracket.forEach((key, value) {
      if (key.startsWith('round_')) {
        final roundNum = int.tryParse(key.replaceFirst('round_', '')) ?? 0;
        maxRound = max(maxRound, roundNum);
      }
    });

    if (maxRound == 0) return false;

    final finalRoundKey = 'round_$maxRound';
    if (!bracket.containsKey(finalRoundKey)) return false;

    final finalMatches = bracket[finalRoundKey] as List;
    if (finalMatches.isEmpty) return false;

    final finalMatch = finalMatches[0] as Map<String, dynamic>;
    return finalMatch['completed'] == true;
  }

  /// Get tournament winner
  static String? getTournamentWinner(Map<String, dynamic> bracket) {
    if (!isTournamentOver(bracket)) return null;

    int maxRound = 0;
    bracket.forEach((key, value) {
      if (key.startsWith('round_')) {
        final roundNum = int.tryParse(key.replaceFirst('round_', '')) ?? 0;
        maxRound = max(maxRound, roundNum);
      }
    });

    final finalRoundKey = 'round_$maxRound';
    if (!bracket.containsKey(finalRoundKey)) return null;

    final finalMatches = bracket[finalRoundKey] as List;
    if (finalMatches.isEmpty) return null;

    final finalMatch = finalMatches[0] as Map<String, dynamic>;
    return finalMatch['winner'] as String?;
  }
}
