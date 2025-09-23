import 'dart:math';

class TicTacToeAI {
  final Random _random = Random();

  // Easy Difficulty: easy to play with,can win easily. Beginners can use this
  List<int> getMove(List<List<String>> board) {
    final emptyCells = <List<int>>[];
    for (int row = 0; row < 3; row++) {
      for (int col = 0; col < 3; col++) {
        if (board[row][col] == '') {
          emptyCells.add([row, col]);
        }
      }
    }
    if (emptyCells.isEmpty) return [-1, -1];
    return emptyCells[_random.nextInt(emptyCells.length)];
  }

  // Medium Difficulty: blocks player win, tries to win but is still beatable
  List<int> getMediumMove(List<List<String>> board, String human, String ai) {
    // less percentage of choosing a random grid instead of blocking win
    if (_random.nextDouble() < 0.3) {
      return getMove(board);
    }
    // Play smart
    // Block player win
    for (int row = 0; row < 3; row++) {
      for (int col = 0; col < 3; col++) {
        if (board[row][col] == '') {
          board[row][col] = human;
          if (_isWinner(board, human)) {
            board[row][col] = '';
            return [row, col];
          }
          board[row][col] = '';
        }
      }
    }
    // Try to win
    for (int row = 0; row < 3; row++) {
      for (int col = 0; col < 3; col++) {
        if (board[row][col] == '') {
          board[row][col] = ai;
          if (_isWinner(board, ai)) {
            board[row][col] = '';
            return [row, col];
          }
          board[row][col] = '';
        }
      }
    }
    // Prioritize centers
    if (board[1][1] == '') return [1, 1];
    // Prioritize corners
    final corners = [
      [0, 0],
      [0, 2],
      [2, 0],
      [2, 2],
    ];
    for (var c in corners) {
      if (board[c[0]][c[1]] == '') return c;
    }
    // Random
    return getMove(board);
  }

  // Hard AI: unbeatable using minimax, randomizes among best moves, prioritizes center/corners
  List<int> getHardMove(List<List<String>> board, String human, String ai) {
    int bestScore = -1000;
    List<List<int>> bestMoves = [];
    for (int row = 0; row < 3; row++) {
      for (int col = 0; col < 3; col++) {
        if (board[row][col] == '') {
          board[row][col] = ai;
          int score = _minimax(board, 0, false, human, ai);
          board[row][col] = '';
          if (score > bestScore) {
            bestScore = score;
            bestMoves = [
              [row, col],
            ];
          } else if (score == bestScore) {
            bestMoves.add([row, col]);
          }
        }
      }
    }
    // Prioritize center/corners among best moves
    final priorities = [
      [1, 1],
      [0, 0],
      [0, 2],
      [2, 0],
      [2, 2],
    ];
    for (var p in priorities) {
      for (var m in bestMoves) {
        if (m[0] == p[0] && m[1] == p[1]) {
          return p;
        }
      }
    }
    // Randomize among best moves
    if (bestMoves.isNotEmpty) {
      return bestMoves[_random.nextInt(bestMoves.length)];
    }
    return [-1, -1];
  }

  int _minimax(
    List<List<String>> board,
    int depth,
    bool isMax,
    String human,
    String ai,
  ) {
    if (_isWinner(board, ai)) return 10 - depth;
    if (_isWinner(board, human)) return depth - 10;
    if (_isDraw(board)) return 0;
    if (isMax) {
      int best = -1000;
      for (int row = 0; row < 3; row++) {
        for (int col = 0; col < 3; col++) {
          if (board[row][col] == '') {
            board[row][col] = ai;
            best = max(best, _minimax(board, depth + 1, false, human, ai));
            board[row][col] = '';
          }
        }
      }
      return best;
    } else {
      int best = 1000;
      for (int row = 0; row < 3; row++) {
        for (int col = 0; col < 3; col++) {
          if (board[row][col] == '') {
            board[row][col] = human;
            best = min(best, _minimax(board, depth + 1, true, human, ai));
            board[row][col] = '';
          }
        }
      }
      return best;
    }
  }

  bool _isDraw(List<List<String>> board) {
    for (var row in board) {
      for (var cell in row) {
        if (cell == '') return false;
      }
    }
    return true;
  }

  bool _isWinner(List<List<String>> board, String player) {
    final combos = [
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
}
