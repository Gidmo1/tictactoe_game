import 'package:flutter_test/flutter_test.dart';
import 'package:tictactoe_game/ai.dart';

void main() {
  final ai = TicTacToeAI();

  group('TicTacToeAI', () {
    test('chooses winning move when available', () {
      final board = List.generate(3, (_) => List.filled(3, ''));
      board[0][0] = 'O';
      board[0][1] = 'O';

      final move = ai.getMoveForLevel(board, 50, 'O', 'X');
      expect(move, equals([0, 2]));
    });

    test('blocks opponent winning move', () {
      final board = List.generate(3, (_) => List.filled(3, ''));
      board[2][0] = 'X';
      board[2][1] = 'X';

      final move = ai.getMoveForLevel(board, 50, 'O', 'X');
      expect(move, equals([2, 2]));
    });

    test('chooses center on empty board', () {
      final board = List.generate(3, (_) => List.filled(3, ''));

      final move = ai.getMoveForLevel(board, 50, 'O', 'X');
      expect(move, equals([1, 1]));
    });
  });
}
