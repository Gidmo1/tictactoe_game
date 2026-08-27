import 'package:flutter_test/flutter_test.dart';
import 'package:tictactoe_game/game_themes/theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('registry exposes every shipped theme and falls back to classic', () {
    expect(GameThemes.all.length, greaterThanOrEqualTo(4));
    expect(GameThemes.byId('classic').name, 'Classic');
    expect(GameThemes.byId('neon').id, 'neon');
    expect(GameThemes.byId('does-not-exist').id, 'classic');
  });

  testWidgets('every theme can rasterize its X, O and button sprites',
      (tester) async {
    await tester.runAsync(() async {
      for (final theme in GameThemes.all) {
        for (final symbol in ['X', 'O']) {
          final sprite = await theme.symbolSprite(symbol, 64);
          expect(sprite.image.width, 64, reason: '${theme.id} $symbol width');
          expect(sprite.image.height, 64, reason: '${theme.id} $symbol height');
          final bytes = await sprite.image.toByteData();
          expect(bytes, isNotNull, reason: '${theme.id} $symbol bytes');
          expect(bytes!.lengthInBytes, greaterThan(0),
              reason: '${theme.id} $symbol not empty');
        }

        final button = await theme.buttonSprite(64, 24);
        final buttonBytes = await button.image.toByteData();
        expect(buttonBytes, isNotNull, reason: '${theme.id} button bytes');
        expect(buttonBytes!.lengthInBytes, greaterThan(0),
            reason: '${theme.id} button not empty');
      }
    });
  });
}