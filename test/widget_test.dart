import 'package:flutter_test/flutter_test.dart';
import 'package:tictactoe_game/tictactoe.dart';

void main() {
  //TestWidgetsFlutterBinding.ensureInitialized();
  test('Test', () async {
    final game = TicTacToeGame();
    await game.onLoad();
  });
}
