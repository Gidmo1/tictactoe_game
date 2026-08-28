import 'dart:math';

import 'tic_tac_toe_rules.dart';

class TicTacToeAI {
  final Random _random = Random();

  List<int> getMoveForLevel(
    List<List<String>> board,
    int level,
    String aiPlayer,
    String humanPlayer, {
    int? winLength,
  }) {
    final target = winLength ?? TicTacToeRules.winLengthFor(board.length);
    final empties = _emptyCells(board);
    if (empties.isEmpty) return [-1, -1];
    if (_random.nextDouble() < _getMistakeChance(level)) {
      return _randomMove(empties);
    }
    final winMove = _findWinningMove(board, aiPlayer, target);
    if (winMove != null) return winMove;
    final blockMove = _findWinningMove(board, humanPlayer, target);
    if (blockMove != null) return blockMove;
    final center = board.length ~/ 2;
    if (board[center][center].isEmpty) return [center, center];
    empties.sort(
      (a, b) =>
          _priority(b, board.length).compareTo(_priority(a, board.length)),
    );
    return empties.first;
  }

  List<List<int>> _emptyCells(List<List<String>> board) {
    final result = <List<int>>[];
    for (var row = 0; row < board.length; row++) {
      for (var col = 0; col < board.length; col++) {
        if (board[row][col].isEmpty) result.add([row, col]);
      }
    }
    return result;
  }

  List<int> _randomMove(List<List<int>> empties) =>
      empties[_random.nextInt(empties.length)];

  List<int>? _findWinningMove(
    List<List<String>> board,
    String player,
    int winLength,
  ) {
    for (final move in _emptyCells(board)) {
      board[move[0]][move[1]] = player;
      final win = TicTacToeRules.checkGameStatus(board, board.length) == player;
      board[move[0]][move[1]] = '';
      if (win) return move;
    }
    return null;
  }

  static bool hasWinner(
    List<List<String>> board,
    String player,
    int winLength,
  ) => TicTacToeRules.checkGameStatus(board, board.length) == player;

  int _priority(List<int> move, int size) {
    final center = (size - 1) / 2;
    return (size * 10 -
            ((move[0] - center).abs() + (move[1] - center).abs()) * 10)
        .round();
  }

  double _getMistakeChance(int level) {
    if (level <= 1) return 0.9;
    if (level <= 10) return 0.6;
    return 0.0;
  }
}
