import 'tic_tac_toe_rules.dart';

class VsComputerMatchConfig {
  final int difficulty;
  final int rounds;
  final String humanPlayer;
  final int gridSize;

  const VsComputerMatchConfig({
    required this.difficulty,
    required this.rounds,
    required this.humanPlayer,
    this.gridSize = 3,
  });

  int get winLength => TicTacToeRules.winLengthFor(gridSize);
}
