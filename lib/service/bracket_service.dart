import 'package:tictactoe_game/models/tournament.dart';

/// Service for generating and managing tournament brackets
class BracketService {
  /// Generate a single-elimination bracket.
  ///
  /// The bracket keeps the existing `round_N` JSON shape because it is already
  /// consumed by the app, but adds source match ids and round deadlines so the
  /// backend can validate transitions and the UI can show pending rounds.
  static Map<String, dynamic> generateSingleElimination(
    List<String> participants, {
    DateTime? startedAt,
    int roundDeadlineHours = 48,
    bool shuffle = true,
    TournamentFormat format = TournamentFormat.flexibleBracket,
  }) {
    final uniqueParticipants = <String>[];
    for (final participant in participants) {
      final normalized = participant.trim();
      if (normalized.isNotEmpty && !uniqueParticipants.contains(normalized)) {
        uniqueParticipants.add(normalized);
      }
    }
    if (uniqueParticipants.length < 2) return {};
    if (roundDeadlineHours < 1) {
      throw ArgumentError.value(
        roundDeadlineHours,
        'roundDeadlineHours',
        'must be at least one hour',
      );
    }

    final bracket = <String, dynamic>{};
    final ordered = List<String>.from(uniqueParticipants);
    if (shuffle) {
      ordered.shuffle();
    }
    final start = startedAt ?? DateTime.now();

    // Round 1 matches
    final round1Matches = <Map<String, dynamic>>[];
    for (int i = 0; i < ordered.length; i += 2) {
      final player1 = ordered[i];
      final player2 = i + 1 < ordered.length ? ordered[i + 1] : null;

      round1Matches.add({
        'id': 'match_1_${i ~/ 2}',
        'round': 1,
        'position': i ~/ 2,
        'player1': player1,
        'player2': player2,
        'winner': null,
        'completed': false,
        'completed_at': null,
        'deadline': start
            .add(Duration(hours: roundDeadlineHours))
            .toIso8601String(),
      });
    }

    bracket['round_1'] = round1Matches;

    // Calculate future rounds
    int currentRound = 1;
    int matchesInRound = round1Matches.length;

    while (matchesInRound > 1) {
      final previousMatchesInRound = matchesInRound;
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
          'completed_at': null,
          'deadline': null,
          'source1': 'match_${currentRound - 1}_${i * 2}',
          'source2': i * 2 + 1 < previousMatchesInRound
              ? 'match_${currentRound - 1}_${i * 2 + 1}'
              : null,
        });
      }
      bracket['round_$currentRound'] = nextRoundMatches;
    }

    bracket['_meta'] = {
      'version': 2,
      'format': format.name,
      'participant_order': ordered,
      'round_deadline_hours': roundDeadlineHours,
      'started_at': start.toIso8601String(),
    };

    _resolveAutomaticAdvances(
      bracket,
      now: start,
      roundDeadlineHours: roundDeadlineHours,
    );

    return bracket;
  }

  /// Generate an official knockout/Cup bracket.
  static Map<String, dynamic> generateCupBracket(
    List<String> participants, {
    DateTime? startedAt,
    int roundDeadlineHours = 48,
    bool shuffle = true,
  }) {
    return generateSingleElimination(
      participants,
      startedAt: startedAt,
      roundDeadlineHours: roundDeadlineHours,
      shuffle: shuffle,
      format: TournamentFormat.cup,
    );
  }

  /// Resolve byes and copy completed winners into the next round.
  ///
  /// This is intentionally iterative. For five players, for example, a bye
  /// in round one creates another bye in round two; both must be resolved
  /// before the final can become playable.
  static bool _resolveAutomaticAdvances(
    Map<String, dynamic> bracket, {
    required DateTime now,
    required int roundDeadlineHours,
  }) {
    var changed = false;
    var progress = true;
    while (progress) {
      progress = false;
      for (var round = 1; bracket.containsKey('round_$round'); round++) {
        final matches = _matchesForRound(bracket, round);
        for (final match in matches) {
          if (match['completed'] == true) {
            _propagateWinner(bracket, match);
            continue;
          }

          final player1 = _stringValue(match['player1']);
          final player2 = _stringValue(match['player2']);
          if (player1 == null && player2 == null) continue;
          if (player1 != null && player2 != null) continue;
          if (!_canResolveBye(bracket, match)) continue;

          final winner = player1 ?? player2;
          match['winner'] = winner;
          match['completed'] = true;
          match['completed_at'] = now.toIso8601String();
          _propagateWinner(bracket, match);
          progress = true;
          changed = true;
        }
      }
    }
    _activateNextRoundDeadline(
      bracket,
      now: now,
      roundDeadlineHours: roundDeadlineHours,
    );
    return changed;
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
        for (final rawMatch in value) {
          if (rawMatch is! Map) continue;
          final match = Map<String, dynamic>.from(rawMatch);
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
    return completeMatchAt(
      bracket,
      matchId,
      winnerUid,
      now: DateTime.now(),
    );
  }

  /// Complete a playable match and advance the winner.
  ///
  /// Returns false for stale, already completed, malformed, or unauthorized
  /// bracket transitions instead of silently corrupting the tournament.
  static bool completeMatchAt(
    Map<String, dynamic> bracket,
    String matchId,
    String winnerUid, {
    required DateTime now,
    int roundDeadlineHours = 48,
  }) {
    // Find the match
    Map<String, dynamic>? matchToComplete;

    bracket.forEach((key, value) {
      if (key.startsWith('round_') && value is List) {
        for (final match in value) {
          if (match is Map && match['id'] == matchId) {
            matchToComplete = match.cast<String, dynamic>();
          }
        }
      }
    });

    if (matchToComplete == null ||
        matchToComplete!['completed'] == true ||
        !_isReady(matchToComplete!) ||
        !_isPlayer(matchToComplete!, winnerUid)) {
      return false;
    }

    // Mark match as complete
    matchToComplete!['completed'] = true;
    matchToComplete!['winner'] = winnerUid;
    matchToComplete!['completed_at'] = now.toIso8601String();

    _propagateWinner(bracket, matchToComplete!);
    _resolveAutomaticAdvances(
      bracket,
      now: now,
      roundDeadlineHours: roundDeadlineHours,
    );
    return true;
  }

  /// Check if tournament is over (final match completed)
  static bool isTournamentOver(Map<String, dynamic> bracket) {
    // Find the final round
    final maxRound = _maxRound(bracket);

    if (maxRound == 0) return false;

    final finalRoundKey = 'round_$maxRound';
    if (!bracket.containsKey(finalRoundKey)) return false;

    final finalMatches = bracket[finalRoundKey] as List;
    if (finalMatches.isEmpty) return false;

    final finalMatch = finalMatches[0];
    return finalMatch is Map &&
        finalMatch['completed'] == true &&
        _stringValue(finalMatch['winner']) != null;
  }

  /// Get tournament winner
  static String? getTournamentWinner(Map<String, dynamic> bracket) {
    if (!isTournamentOver(bracket)) return null;

    final maxRound = _maxRound(bracket);

    final finalRoundKey = 'round_$maxRound';
    if (!bracket.containsKey(finalRoundKey)) return null;

    final finalMatches = bracket[finalRoundKey] as List;
    if (finalMatches.isEmpty) return null;

    final finalMatch = finalMatches[0];
    return finalMatch is Map ? _stringValue(finalMatch['winner']) : null;
  }

  /// A match can be forfeited only after its round deadline.
  static bool isPastDeadline(
    Map<String, dynamic> match, {
    DateTime? now,
  }) {
    final rawDeadline = match['deadline']?.toString();
    final deadline = rawDeadline == null ? null : DateTime.tryParse(rawDeadline);
    return deadline != null && (now ?? DateTime.now()).isAfter(deadline);
  }

  static List<Map<String, dynamic>> _matchesForRound(
    Map<String, dynamic> bracket,
    int round,
  ) {
    final raw = bracket['round_$round'];
    if (raw is! List) return [];
    return raw.whereType<Map>().map((match) {
      return match.cast<String, dynamic>();
    }).toList();
  }

  static int _maxRound(Map<String, dynamic> bracket) {
    var maxRound = 0;
    for (final key in bracket.keys) {
      if (key.startsWith('round_')) {
        maxRound = _max(maxRound, int.tryParse(key.substring(6)) ?? 0);
      }
    }
    return maxRound;
  }

  static int _max(int a, int b) => a > b ? a : b;

  static String? _stringValue(dynamic value) {
    final text = value?.toString();
    return text == null || text.isEmpty ? null : text;
  }

  static bool _isReady(Map match) =>
      _stringValue(match['player1']) != null &&
      _stringValue(match['player2']) != null;

  static bool _isPlayer(Map match, String uid) =>
      match['player1'] == uid || match['player2'] == uid;

  static bool _canResolveBye(
    Map<String, dynamic> bracket,
    Map<String, dynamic> match,
  ) {
    final round = (match['round'] as num?)?.toInt() ?? 1;
    if (round == 1) return true;

    final source1 = _findMatch(bracket, match['source1']?.toString());
    final source2 = _findMatch(bracket, match['source2']?.toString());
    if (source1 == null && source2 == null) return false;
    if (source1 != null && source1['completed'] != true) return false;
    if (source2 != null && source2['completed'] != true) return false;
    return true;
  }

  static Map<String, dynamic>? _findMatch(
    Map<String, dynamic> bracket,
    String? matchId,
  ) {
    if (matchId == null) return null;
    for (final value in bracket.values) {
      if (value is! List) continue;
      for (final rawMatch in value) {
        if (rawMatch is Map && rawMatch['id'] == matchId) {
          return rawMatch.cast<String, dynamic>();
        }
      }
    }
    return null;
  }

  static void _propagateWinner(
    Map<String, dynamic> bracket,
    Map<String, dynamic> match,
  ) {
    final winner = _stringValue(match['winner']);
    if (winner == null) return;
    final round = (match['round'] as num?)?.toInt() ?? 0;
    final position = (match['position'] as num?)?.toInt() ?? 0;
    final nextMatches = _matchesForRound(bracket, round + 1);
    if (nextMatches.isEmpty) return;

    final nextMatch = nextMatches[position ~/ 2];
    if (position.isEven) {
      nextMatch['player1'] = winner;
    } else {
      nextMatch['player2'] = winner;
    }
  }

  static void _activateNextRoundDeadline(
    Map<String, dynamic> bracket, {
    required DateTime now,
    required int roundDeadlineHours,
  }) {
    final deadline = now.add(Duration(hours: roundDeadlineHours)).toIso8601String();
    for (var round = 1; round <= _maxRound(bracket); round++) {
      final matches = _matchesForRound(bracket, round);
      final hasPlayableMatch = matches.any(
        (match) =>
            match['completed'] != true &&
            _isReady(match),
      );
      if (!hasPlayableMatch) continue;
      for (final match in matches) {
        if (match['completed'] != true && _isReady(match)) {
          match['deadline'] ??= deadline;
        }
      }
      return;
    }
  }
}
