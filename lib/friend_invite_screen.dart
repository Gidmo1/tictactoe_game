import 'dart:math';
import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flame/events.dart';
import 'package:flame_audio/flame_audio.dart';
import 'package:flutter/material.dart' hide Route;
import 'package:flutter/services.dart';
import 'package:tictactoe_game/settings_screen.dart';
import 'tictactoe.dart';
import 'dart:async';
import 'service/supabase_match_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FriendInviteComponent extends PositionComponent
    with HasGameReference<TicTacToeGame>, TapCallbacks {
  static const int codeLength = 6;
  String? generatedCode; // 6-digit string
  String input = '';

  FriendInviteComponent();

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    size = game.size;

    // Full-screen background sprite
    final bg = SpriteComponent()
      ..sprite =
          await (findGame()?.loadSprite('background.png') ??
              Sprite.load('background.png'))
      ..size = size
      ..position = Vector2.zero()
      ..priority = 0;
    add(bg);

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
    // Buttons
    final returnSprite = await game.loadSprite('return.png');
    add(
      _ReturnButton(
        sprite: returnSprite,
        position: Vector2(10, 40),
        onPressed: () => game.router.pushReplacementNamed('menu'),
      ),
    );
    // Host text
    add(
      TextComponent(
        text: 'Host (Generate)',
        position: Vector2(size.x * 0.25, 110),
        anchor: Anchor.center,
        textRenderer: TextPaint(
          style: const TextStyle(color: Colors.white, fontSize: 14),
        ),
        priority: 11010,
      ),
    );

    // Join text
    add(
      TextComponent(
        text: 'Join (Enter code)',
        position: Vector2(size.x * 0.75, 100),
        anchor: Anchor.center,
        textRenderer: TextPaint(
          style: const TextStyle(color: Colors.white, fontSize: 14),
        ),
        priority: 11010,
      ),
    );

    final genSprite = await game.loadSprite('generate_code.png');
    final joinSprite = await game.loadSprite('join_match.png');

    // Generate Code button
    add(
      _SpriteButton(
        sprite: genSprite,
        position: Vector2(size.x * 0.25, 150),
        size: Vector2(160, 64),
        onPressed: () async {
          await startGenerateFlow();
        },
      ),
    );

    // Join Match button
    add(
      _SpriteButton(
        sprite: joinSprite,
        position: Vector2(size.x * 0.75, 150),
        size: Vector2(160, 64),
        onPressed: () async {
          // Start the join flow
          await startJoinFlow();
        },
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
    String? usedCode;
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

        if (createdMatchId == null || createdMatchId!.isEmpty || inviteCode.isEmpty) {
          throw StateError('Supabase create_match returned no match data');
        }

        generatedCode = inviteCode.toUpperCase();
        usedCode = generatedCode;
        createdOnServer = true;

        try {
          await Clipboard.setData(ClipboardData(text: generatedCode!));
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

    if (!createdOnServer || createdMatchId == null || createdMatchId!.isEmpty) {
      showTransientMessage('Failed to create invite. Try again later.');
      await Future.delayed(const Duration(milliseconds: 1500));
      codeDisplay.removeFromParent();
      return;
    }

    final matchId = createdMatchId!;
    try {
      game.pendingMatchId = matchId;
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
      try {
        if (game.overlays.isActive('code_input'))
          game.overlays.remove('code_input');
      } catch (_) {}
      game.children.whereType<FriendLobbyComponent>().forEach(
        (c) => c.removeFromParent(),
      );
      final lobby = FriendLobbyComponent(matchId: matchId);
      lobby.priority = 1000000000000;
      game.add(lobby);
    } catch (e) {
      debugPrint('Failed to add FriendLobbyComponent: $e');
    }
  }

  // Start the join flow
  Future<void> startJoinFlow() async {
    input = '';
    final inputDisplay = _InputDisplay(
      () => input,
      position: Vector2(size.x * 0.75, 140),
      onTap: () {
        if (!game.overlays.isActive('code_input'))
          game.overlays.add('code_input');
      },
    );
    add(inputDisplay);
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

  String _randomCode() {
    const chars = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
    final rand = Random();
    final sb = StringBuffer();
    for (var i = 0; i < codeLength; i++) {
      sb.write(chars[rand.nextInt(chars.length)]);
    }
    return sb.toString();
  }
}

class FriendLobbyComponent extends PositionComponent
    with HasGameReference<TicTacToeGame> {
  final String matchId;
  StreamSubscription<dynamic>? _sub;

  FriendLobbyComponent({required this.matchId});

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    size = game.size;

    // small dialog
    final w = size.x * 0.8;
    // Overlay
    final h = (w * 0.6).clamp(140.0, 260.0);
    final dialogPos = Vector2((size.x - w) / 2, (size.y - h) / 2);
    final overlaySprite = await game.loadSprite('confirmation_overlay.png');
    final dialogSprite = SpriteComponent(
      sprite: overlaySprite,
      size: Vector2(w, h),
      position: dialogPos,
      anchor: Anchor.topLeft,
    );
    // ensure the dialog sprite renders above other components
    dialogSprite.priority = 10001;
    add(dialogSprite);

    final title = TextComponent(
      text: 'Waiting for your friend to join...',
      position: dialogPos + Vector2(w / 2, 12),
      anchor: Anchor.topCenter,
      textRenderer: TextPaint(
        style: const TextStyle(color: Colors.white, fontSize: 16),
      ),
      priority: 11040,
    );
    add(title);

    // status text component
    final statusText = TextComponent(
      text: 'Status: waiting',
      position: dialogPos + Vector2(w / 2, 48),
      anchor: Anchor.topCenter,
      textRenderer: TextPaint(style: const TextStyle(color: Colors.white70)),
      priority: 11040,
    );
    add(statusText);

    final cancelBtn = _LabelButton(
      label: 'Cancel',
      position: dialogPos + Vector2((w / 2) - 60, 96),
      btnSize: Vector2(120, 44),
      onPressed: () async {
        // Clear client-side pending match state immediately so UI responds.
        game.pendingMatchId = null;
        game.myPlayerSymbol = null;

        // Also clear any generated invite code that may be displayed by any
        // FriendInviteComponent instance
        try {
          void clearRec(Component c) {
            try {
              if (c.runtimeType.toString() == 'FriendInviteComponent') {
                try {
                  // Use dynamic access to avoid type resolution issues
                  (c as dynamic).generatedCode = null;
                  (c as dynamic).input = '';
                } catch (_) {}
              }
            } catch (_) {}
            try {
              for (final child in c.children) {
                clearRec(child);
              }
            } catch (_) {}
          }

          clearRec(game);
          try {
            clearRec(game.router);
          } catch (_) {}
        } catch (_) {}

        try {
          await SupabaseMatchService().cancelMatch(matchId: matchId);
        } catch (e) {
          debugPrint('Supabase cancelMatch failed: $e');
        }

        try {
          // If we're not already on the invite-options route, replace the route so the invite options screen will be visible
          if (game.currentRoute != 'invite_options') {
            game.router.pushReplacementNamed('invite_options');
          }
        } catch (_) {}

        // show a small notice on the game
        try {
          final cancelNotice = TextComponent(
            text: 'Match cancelled',
            position: Vector2(game.size.x / 2, 80),
            anchor: Anchor.center,
            textRenderer: TextPaint(
              style: const TextStyle(color: Colors.white),
            ),
          )..priority = 1103000;
          game.add(cancelNotice);
          Future.delayed(const Duration(milliseconds: 900), () {
            try {
              cancelNotice.removeFromParent();
            } catch (_) {}
          });
        } catch (_) {}

        // Remove the lobby component and keep the game running underneath
        removeFromParent();
      },
    );
    // ensure the cancel button sits above the lobby background
    cancelBtn.priority = 11060;
    add(cancelBtn);

  }

  @override
  void onRemove() {
    try {
      _sub?.cancel();
    } catch (_) {}
    super.onRemove();
  }
}

// Small Flame UI helpers
class _LabelButton extends PositionComponent with TapCallbacks {
  final String label;
  final void Function() onPressed;

  _LabelButton({
    required this.label,
    required Vector2 position,
    required Vector2 btnSize,
    required this.onPressed,
  }) : super(position: position, size: btnSize, anchor: Anchor.topLeft);

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    add(
      RectangleComponent(
        size: size,
        position: Vector2.zero(),
        paint: Paint()..color = Colors.white.withOpacity(0.08),
      ),
    );
    add(
      TextComponent(
        text: label,
        position: size / 2,
        anchor: Anchor.center,
        textRenderer: TextPaint(style: const TextStyle(color: Colors.white)),
        priority: 11060,
      ),
    );
  }

  @override
  void onTapDown(TapDownEvent event) {
    onPressed();
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

class _InputDisplay extends PositionComponent with TapCallbacks {
  final String Function() getter;
  final void Function()? onTap;
  _InputDisplay(this.getter, {required Vector2 position, this.onTap})
    // Match the code display size so the tap target and visuals align
    : super(position: position, size: Vector2(160, 60), anchor: Anchor.center);

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    add(
      RectangleComponent(
        size: size,
        position: Vector2.zero(),
        paint: Paint()..color = Colors.white.withOpacity(0.06),
      ),
    );
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
  void onTapDown(TapDownEvent event) {
    if (onTap != null) onTap!();
  }

  @override
  void update(double dt) {
    super.update(dt);
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

class _ReturnButton extends SpriteComponent with TapCallbacks {
  final VoidCallback onPressed;
  _ReturnButton({
    required Sprite sprite,
    required Vector2 position,
    required this.onPressed,
  }) : super(sprite: sprite, size: Vector2(50, 50), position: position);

  @override
  void onTapDown(TapDownEvent event) {
    if (SettingsScreen.buttonSoundOn) FlameAudio.play('button.wav');
    add(
      SequenceEffect([
        ScaleEffect.to(Vector2(0.9, 0.9), EffectController(duration: 0.05)),
        ScaleEffect.to(
          Vector2(1.05, 1.05),
          EffectController(duration: 0.08, curve: Curves.easeOut),
        ),
        ScaleEffect.to(
          Vector2(1.0, 1.0),
          EffectController(duration: 0.05, curve: Curves.easeIn),
        ),
      ]),
    );
    Future.delayed(const Duration(milliseconds: 150), () => onPressed());
  }
}

//Sprite Button
class _SpriteButton extends SpriteComponent with TapCallbacks {
  final VoidCallback onPressed;
  _SpriteButton({
    required Sprite sprite,
    required Vector2 position,
    required Vector2 size,
    required this.onPressed,
  }) : super(
         sprite: sprite,
         size: size,
         position: position,
         anchor: Anchor.center,
       );

  @override
  void onTapDown(TapDownEvent event) {
    if (SettingsScreen.buttonSoundOn) FlameAudio.play('button.wav');
    add(
      SequenceEffect([
        ScaleEffect.to(Vector2(0.9, 0.9), EffectController(duration: 0.05)),
        ScaleEffect.to(
          Vector2(1.05, 1.05),
          EffectController(duration: 0.08, curve: Curves.easeOut),
        ),
        ScaleEffect.to(
          Vector2(1.0, 1.0),
          EffectController(duration: 0.05, curve: Curves.easeIn),
        ),
      ]),
    );
    Future.delayed(const Duration(milliseconds: 150), onPressed);
  }
}
