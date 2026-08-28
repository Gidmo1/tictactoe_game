import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flutter/material.dart' hide Route;
import 'package:flutter/services.dart';
import 'tictactoe.dart';
import 'service/supabase_match_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'components/button.dart';
import 'game_themes/theme_store.dart';

class FriendInviteComponent extends PositionComponent
    with HasGameReference<TicTacToeGame>, TapCallbacks {
  static const int codeLength = 8;
  String? generatedCode;
  String input = '';

  FriendInviteComponent();

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    size = game.size;

    add(
      RectangleComponent(
        size: size,
        position: Vector2.zero(),
        paint: Paint()..color = ThemeStore.current.boardBackground,
      ),
    );

    // Title
    add(
      TextComponent(
        text: 'Play with a Friend',
        position: Vector2(size.x / 2, 48),
        anchor: Anchor.center,
        textRenderer: TextPaint(
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        priority: 11010,
      ),
    );
    add(
      ButtonComponent(
        label: 'BACK',
        position: Vector2(size.x / 2, 70),
        size: Vector2(110, 42),
        theme: ThemeStore.current,
        onPressed: () => game.router.pushReplacementNamed('menu'),
      ),
    );
    // Use the current procedural themed controls for online play.
    add(
      TextComponent(
        text: 'Create a private match',
        position: Vector2(size.x / 2, 150),
        anchor: Anchor.center,
        textRenderer: TextPaint(
          style: const TextStyle(color: Colors.white, fontSize: 14),
        ),
        priority: 11010,
      ),
    );

    add(
      TextComponent(
        text: 'Have an invite code?',
        position: Vector2(size.x / 2, 280),
        anchor: Anchor.center,
        textRenderer: TextPaint(
          style: const TextStyle(color: Colors.white, fontSize: 14),
        ),
        priority: 11010,
      ),
    );

    add(
      ButtonComponent(
        label: 'CREATE MATCH',
        position: Vector2(size.x / 2, 205),
        size: Vector2(size.x * 0.72, 56),
        theme: ThemeStore.current,
        onPressed: startGenerateFlow,
      ),
    );

    add(
      ButtonComponent(
        label: 'ENTER INVITE CODE',
        position: Vector2(size.x / 2, 335),
        size: Vector2(size.x * 0.72, 56),
        theme: ThemeStore.current,
        onPressed: startJoinFlow,
      ),
    );
  }

  Future<void> startGenerateFlow() async {
    if (!await game.requireSignedInForOnlineAction()) {
      return;
    }

    // Clear any previous generated value(code that was formerly generated)
    generatedCode = null;
    // Show code display immediately
    final codeDisplay = _CodeDisplay(
      () => generatedCode ?? '',
      position: Vector2(size.x / 2, 230),
    );
    add(codeDisplay);

    // Attempt to create the match on server
    int attempts = 0;
    const maxAttempts = 4;
    bool createdOnServer = false;
    String? createdMatchId;

    while (attempts < maxAttempts && !createdOnServer) {
      attempts += 1;
      try {
        final match = await SupabaseMatchService().createMatch(
          boardSize: 3,
          winLength: 3,
        );
        createdMatchId = match['id']?.toString();
        final inviteCode = (match['invite_code'] ?? '').toString();
        final matchId = createdMatchId;

        if (matchId == null || matchId.isEmpty || inviteCode.isEmpty) {
          throw StateError('Supabase create_match returned no match data');
        }

        generatedCode = inviteCode.toUpperCase();
        createdOnServer = true;

        try {
          await Clipboard.setData(ClipboardData(text: generatedCode ?? ''));
        } catch (_) {}
        final copiedNotice = TextComponent(
          text: 'Code copied',
          position: Vector2(game.size.x * 0.25, 220),
          anchor: Anchor.center,
          textRenderer: TextPaint(
            style: const TextStyle(color: Colors.white, fontSize: 14),
          ),
        )..priority = 11020;
        game.add(copiedNotice);
        Future.delayed(
          const Duration(milliseconds: 1200),
          () => copiedNotice.removeFromParent(),
        );
      } catch (e) {
        debugPrint('createMatch callable error: $e');
        showTransientMessage('Server error, retrying...');
        await Future.delayed(const Duration(milliseconds: 900));
        continue;
      }
    }

    final matchId = createdMatchId;
    if (!createdOnServer || matchId == null || matchId.isEmpty) {
      showTransientMessage('Failed to create invite. Try again later.');
      await Future.delayed(const Duration(milliseconds: 1500));
      codeDisplay.removeFromParent();
      return;
    }

    try {
      game.pendingMatchId = matchId;
      game.pendingInviteCode = generatedCode;
      try {
        final prefs = await SharedPreferences.getInstance();
        final humanIsX = prefs.getBool('human_is_x') ?? true;
        game.myPlayerSymbol = humanIsX ? 'X' : 'O';
      } catch (_) {
        game.myPlayerSymbol = 'X';
      }
      try {
        game.stopMenuMusic();
      } catch (_) {}
    } catch (e) {
      debugPrint('Error setting pending match state: $e');
    }

    try {
      if (game.overlays.isActive('code_input')) {
        game.overlays.remove('code_input');
      }
      game.openMatchWithId(matchId, isCreator: true);
    } catch (e) {
      debugPrint('Failed to open Supabase match: $e');
    }
  }

  // Start the join flow
  Future<void> startJoinFlow() async {
    input = '';
    game.overlays.add('code_input');
  }

  // input is updated in-place, UI will read from the getter each frame.
  Future<void> attemptJoin(String code) async {
    if (!await game.requireSignedInForOnlineAction()) {
      return;
    }

    if (code.length != codeLength) {
      showTransientMessage('Code must be $codeLength chars');
      return;
    }
    final matchCode = code.toUpperCase();
    try {
      final match = await SupabaseMatchService().joinMatch(matchId: matchCode);
      final joinedMatchId = match['id']?.toString();
      if (joinedMatchId != null && joinedMatchId.isNotEmpty) {
        showTransientMessage('Joined match');
        game.openMatchWithId(joinedMatchId, isCreator: false);
        removeFromParent();
        return;
      }

      showTransientMessage('Unable to join');
      return;
    } catch (e) {
      debugPrint('joinMatch Supabase error: $e');
      showTransientMessage('Failed to join. Try again.');
    }
  }

  void showTransientMessage(String text, {int ms = 900}) {
    final notice = TextComponent(
      text: text,
      position: Vector2(game.size.x / 2, 80),
      anchor: Anchor.center,
      textRenderer: TextPaint(style: const TextStyle(color: Colors.white)),
    )..priority = 11030;
    game.add(notice);
    Future.delayed(Duration(milliseconds: ms), () => notice.removeFromParent());
  }

}

class _CodeDisplay extends PositionComponent {
  final String Function() getter;
  _CodeDisplay(this.getter, {required Vector2 position})
    : super(position: position, size: Vector2(160, 60), anchor: Anchor.center);

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    add(
      TextComponent(
        text: getter(),
        position: size / 2,
        anchor: Anchor.center,
        textRenderer: TextPaint(
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            letterSpacing: 6,
          ),
        ),
      ),
    );
  }

  @override
  void update(double dt) {
    super.update(dt);
    // Update displayed text if it changed
    final txt = getter();
    children.whereType<TextComponent>().forEach((t) {
      if (t.text != txt) t.text = txt;
    });
  }
}

// Wrapper so the invite UI can be used as a Router route
class FriendInviteScreen extends Component {
  @override
  Future<void> onLoad() async {
    await super.onLoad();
    add(FriendInviteComponent());
  }
}


