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

    test('detects four in a row on a 4x4 board', () {
      final board = List.generate(4, (_) => List.filled(4, ''));
      for (var col = 0; col < 3; col++) {
        board[1][col] = 'O';
      }

      final move = ai.getMoveForLevel(board, 50, 'O', 'X', winLength: 4);
      expect(move, equals([1, 3]));
    });

    test('blocks five in a row on a 10x10 board', () {
      final board = List.generate(10, (_) => List.filled(10, ''));
      for (var col = 0; col < 4; col++) {
        board[6][col] = 'X';
      }

      final move = ai.getMoveForLevel(board, 50, 'O', 'X', winLength: 5);
      expect(move, equals([6, 4]));
    });
  });
}
