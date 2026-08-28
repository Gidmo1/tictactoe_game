import 'package:flutter_test/flutter_test.dart';
import 'package:tictactoe_game/tic_tac_toe_rules.dart';

void main() {
  test('3x3 declares a three-in-a-row winner', () {
    final board = List.generate(3, (_) => List.filled(3, ''));
    board[0][0] = 'X';
    board[0][1] = 'X';
    board[0][2] = 'X';

    expect(TicTacToeRules.checkGameStatus(board, 3), 'X');
  });

  test('4x4 requires four in a row', () {
    final board = List.generate(4, (_) => List.filled(4, ''));
    board[0][0] = 'O';
    board[0][1] = 'O';
    board[0][2] = 'O';

    expect(TicTacToeRules.checkGameStatus(board, 4), isNull);
    board[0][3] = 'O';
    expect(TicTacToeRules.checkGameStatus(board, 4), 'O');
  });

  test('5x5 uses five in a row', () {
    final board = List.generate(5, (_) => List.filled(5, ''));
    for (var index = 0; index < 5; index++) {
      board[index][index] = 'X';
    }

    expect(TicTacToeRules.checkGameStatus(board, 5), 'X');
  });

  test('10x10 uses five in a row and supports sliding windows', () {
    final board = List.generate(10, (_) => List.filled(10, ''));
    for (var col = 2; col < 7; col++) {
      board[8][col] = 'O';
    }

    expect(TicTacToeRules.checkGameStatus(board, 10), 'O');
  });
}
