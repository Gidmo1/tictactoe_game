import 'dart:math';

class TicTacToeAI {
  final Random _random = Random();

  List<int> getMoveForLevel(
    List<List<String>> board,
    int level,
    String aiPlayer,
    String humanPlayer,
  ) {
    final empties = _emptyCells(board);
    if (empties.isEmpty) return [-1, -1];

    // AI mistake chance (based on level)
    final mistakeChance = _getMistakeChance(level);

    // Decide whether AI will play dumb or smart
    if (_random.nextDouble() < mistakeChance) {
      return _randomMove(board); // make a dumb move
    }

    // Try to win or block, else random
    final winMove = _findWinningMove(board, aiPlayer);
    if (winMove != null) return winMove;

    final blockMove = _findWinningMove(board, humanPlayer);
    if (blockMove != null) return blockMove;

    // Try center
    if (board[1][1] == '') return [1, 1];

    // Try corners
    final corners = [
      [0, 0],
      [0, 2],
      [2, 0],
      [2, 2],
    ];
    corners.shuffle(_random);
    for (var c in corners) {
      if (board[c[0]][c[1]] == '') return c;
    }

    // Otherwise random
    return _randomMove(board);
  }

  // ---------------------------
  // HELPERS
  // ---------------------------

  List<List<int>> _emptyCells(List<List<String>> board) {
    final empties = <List<int>>[];
    for (int r = 0; r < 3; r++) {
      for (int c = 0; c < 3; c++) {
        if (board[r][c] == '') empties.add([r, c]);
      }
    }
    return empties;
  }

  List<int> _randomMove(List<List<String>> board) {
    final empties = _emptyCells(board);
    if (empties.isEmpty) return [-1, -1];
    return empties[_random.nextInt(empties.length)];
  }

  List<int>? _findWinningMove(List<List<String>> board, String player) {
    for (int r = 0; r < 3; r++) {
      for (int c = 0; c < 3; c++) {
        if (board[r][c] == '') {
          board[r][c] = player;
          final isWin = _isWinner(board, player);
          board[r][c] = '';
          if (isWin) return [r, c];
        }
      }
    }
    return null;
  }

  bool _isWinner(List<List<String>> board, String player) {
    const combos = [
      // rows
      [
        [0, 0],
        [0, 1],
        [0, 2],
      ],
      [
        [1, 0],
        [1, 1],
        [1, 2],
      ],
      [
        [2, 0],
        [2, 1],
        [2, 2],
      ],
      // columns
      [
        [0, 0],
        [1, 0],
        [2, 0],
      ],
      [
        [0, 1],
        [1, 1],
        [2, 1],
      ],
      [
        [0, 2],
        [1, 2],
        [2, 2],
      ],
      // diagonals
      [
        [0, 0],
        [1, 1],
        [2, 2],
      ],
      [
        [0, 2],
        [1, 1],
        [2, 0],
      ],
    ];

    for (var combo in combos) {
      if (board[combo[0][0]][combo[0][1]] == player &&
          board[combo[1][0]][combo[1][1]] == player &&
          board[combo[2][0]][combo[2][1]] == player) {
        return true;
      }
    }
    return false;
  }

  double _getMistakeChance(int level) {
    // Higher level = fewer mistakes
    if (level <= 1) return 0.9; // 90% dumb
    if (level <= 10) return 0.6;
    if (level <= 20) return 0.4;
    if (level <= 30) return 0.2;
    if (level < 50) return 0.1;
    return 0.0; // level 50+ = no mistakes
  }
}
