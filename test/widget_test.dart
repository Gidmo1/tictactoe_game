import 'package:flutter_test/flutter_test.dart';
import 'package:tictactoe_game/tictactoe.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('Test', () async {
    // Do not call onLoad here because it initializes Firebase which
    // requires platform channels not available in this test environment.
    final game = TicTacToeGame();
    expect(game, isNotNull);
  });
}
