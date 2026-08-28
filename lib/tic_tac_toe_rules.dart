class BoardConfig {
  final int size;
  final int winCondition;

  const BoardConfig({required this.size, required this.winCondition});
}

class TicTacToeRules {
  static const Map<int, BoardConfig> configs = {
    3: BoardConfig(size: 3, winCondition: 3),
    4: BoardConfig(size: 4, winCondition: 4),
    5: BoardConfig(size: 5, winCondition: 5),
    6: BoardConfig(size: 6, winCondition: 5),
    7: BoardConfig(size: 7, winCondition: 5),
    8: BoardConfig(size: 8, winCondition: 5),
    9: BoardConfig(size: 9, winCondition: 5),
    10: BoardConfig(size: 10, winCondition: 5),
  };

  static int winLengthFor(int size) {
    final config = configs[size];
    if (config == null) {
      throw ArgumentError('Unsupported board size: $size');
    }
    return config.winCondition;
  }

  static String? checkGameStatus(List<List<String>> board, int size) {
    final winLength = winLengthFor(size);

    for (var row = 0; row < size; row++) {
      for (var col = 0; col <= size - winLength; col++) {
        final player = board[row][col];
        if (player.isNotEmpty &&
            _matches(board, row, col, 0, 1, player, winLength)) {
          return player;
        }
      }
    }

    for (var col = 0; col < size; col++) {
      for (var row = 0; row <= size - winLength; row++) {
        final player = board[row][col];
        if (player.isNotEmpty &&
            _matches(board, row, col, 1, 0, player, winLength)) {
          return player;
        }
      }
    }

    for (var row = 0; row <= size - winLength; row++) {
      for (var col = 0; col <= size - winLength; col++) {
        final player = board[row][col];
        if (player.isNotEmpty &&
            _matches(board, row, col, 1, 1, player, winLength)) {
          return player;
        }
      }
    }

    for (var row = 0; row <= size - winLength; row++) {
      for (var col = winLength - 1; col < size; col++) {
        final player = board[row][col];
        if (player.isNotEmpty &&
            _matches(board, row, col, 1, -1, player, winLength)) {
          return player;
        }
      }
    }

    for (final row in board) {
      if (row.contains('')) return null;
    }
    return 'Draw';
  }

  static bool _matches(
    List<List<String>> board,
    int row,
    int col,
    int rowStep,
    int colStep,
    String player,
    int length,
  ) {
    for (var step = 1; step < length; step++) {
      if (board[row + rowStep * step][col + colStep * step] != player) {
        return false;
      }
    }
    return true;
  }
}
