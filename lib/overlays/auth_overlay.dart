import 'package:flame/game.dart';
import 'package:tictactoe_game/components/auth_gate_component.dart';
import 'package:tictactoe_game/tictactoe.dart';

/// Helper to show a Flame `AuthGateComponent` reliably.
/// Removes any existing auth gates before adding a fresh one.
Future<void> showAuthGate(
  FlameGame game, {
  void Function()? onSignedIn,
  bool nonDismissible = false,
}) async {
  try {
    // If caller provided an onSignedIn callback, store it on the game so
    // the Flutter overlay (which is added by AuthGateComponent) can call
    // it after a successful sign-in.
    try {
      if (game is TicTacToeGame) {
        game.pendingAuthOnSignedIn = onSignedIn;
      }
    } catch (_) {}
    // remove any existing gates
    final existing = List<AuthGateComponent>.from(
      game.children.whereType<AuthGateComponent>(),
    );
    for (final e in existing) {
      try {
        e.removeFromParent();
      } catch (_) {}
    }
    // Ensure any Flutter-based auth overlays are removed so we don't stack UIs.
    try {
      game.overlays.remove('auth_gate');
      game.overlays.remove('edit_profile');
      game.overlays.remove('edit_profile_inline');
    } catch (_) {}

    // create and add a fresh gate
    final gate = AuthGateComponent(
      onSignedIn: onSignedIn,
      nonDismissible: nonDismissible,
    );
    gate.priority = 1006000000000;
    game.add(gate);
  } catch (e) {
    // ignore: avoid_print
    print('showAuthGate failed: $e');
  }
}
