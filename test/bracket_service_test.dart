import 'package:flutter_test/flutter_test.dart';
import 'package:tictactoe_game/service/bracket_service.dart';

void main() {
  final startedAt = DateTime.utc(2026, 1, 1);

  group('BracketService', () {
    test('rejects fewer than two unique participants', () {
      expect(
        BracketService.generateSingleElimination(
          ['alice', 'alice', ''],
          startedAt: startedAt,
          shuffle: false,
        ),
        isEmpty,
      );
    });

    test('resolves an odd-player bye without creating a dangling final', () {
      final bracket = BracketService.generateSingleElimination(
        ['alice', 'bob', 'carol'],
        startedAt: startedAt,
        shuffle: false,
      );

      final roundOne = bracket['round_1'] as List;
      final bye = roundOne[1] as Map;
      expect(bye['completed'], isTrue);
      expect(bye['winner'], 'carol');

      final pending = BracketService.getPendingMatches(bracket);
      expect(pending, hasLength(1));
      expect(pending.single['round'], 1);
      expect(pending.single['player1'], 'alice');
      expect(pending.single['player2'], 'bob');
    });

    test('advances the winner into the next round and completes a three-player cup',
        () {
      final bracket = BracketService.generateSingleElimination(
        ['alice', 'bob', 'carol'],
        startedAt: startedAt,
        shuffle: false,
      );

      expect(
        BracketService.completeMatchAt(
          bracket,
          'match_1_0',
          'alice',
          now: startedAt.add(const Duration(hours: 1)),
        ),
        isTrue,
      );

      final finalMatch = BracketService.getNextMatchForParticipant(
        bracket,
        'alice',
      );
      expect(finalMatch, isNotNull);
      expect(finalMatch!['player1'], 'alice');
      expect(finalMatch['player2'], 'carol');

      expect(
        BracketService.completeMatchAt(
          bracket,
          finalMatch['id'] as String,
          'carol',
          now: startedAt.add(const Duration(hours: 2)),
        ),
        isTrue,
      );
      expect(BracketService.isTournamentOver(bracket), isTrue);
      expect(BracketService.getTournamentWinner(bracket), 'carol');
    });

    test('does not accept a winner who is not in the match', () {
      final bracket = BracketService.generateSingleElimination(
        ['alice', 'bob'],
        startedAt: startedAt,
        shuffle: false,
      );

      expect(
        BracketService.completeMatchAt(
          bracket,
          'match_1_0',
          'carol',
          now: startedAt,
        ),
        isFalse,
      );
      expect(BracketService.getPendingMatches(bracket), hasLength(1));
    });

    test('attaches a round deadline and detects expiry', () {
      final bracket = BracketService.generateSingleElimination(
        ['alice', 'bob'],
        startedAt: startedAt,
        roundDeadlineHours: 48,
        shuffle: false,
      );
      final match = BracketService.getPendingMatches(bracket).single;

      expect(
        match['deadline'],
        startedAt.add(const Duration(hours: 48)).toIso8601String(),
      );
      expect(
        BracketService.isPastDeadline(
          match,
          now: startedAt.add(const Duration(hours: 49)),
        ),
        isTrue,
      );
    });
  });
}