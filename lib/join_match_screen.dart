import 'dart:async';
import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flame/events.dart';
import 'package:flame_audio/flame_audio.dart';
import 'package:flutter/material.dart' hide Route;
import 'package:cloud_functions/cloud_functions.dart';
import 'package:tictactoe_game/settings_screen.dart';
import 'tictactoe.dart';
import 'service/guest_service.dart';

class JoinMatchScreen extends Component with HasGameReference<TicTacToeGame> {
  String input = '';

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    final bg = SpriteComponent()
      ..sprite = await game.loadSprite('background.png')
      ..size = game.size
      ..position = Vector2.zero()
      ..priority = 0;

    add(bg);

    // Return button
    /*final returnSprite = await game.loadSprite('return.png');
    add(
      _ReturnButton(
        sprite: returnSprite,
        position: Vector2(10, 40),
        onPressed: () => game.router.pushReplacementNamed('invite_options'),
      ),
    );*/

    // Label above input box
    add(
      TextComponent(
        text: 'Enter a code',
        position: Vector2(game.size.x / 2, 90),
        anchor: Anchor.center,
        textRenderer: TextPaint(
          style: const TextStyle(color: Colors.white, fontSize: 22),
        ),
        priority: 11010,
      ),
    );

    final inputDisplay = _InputDisplay(
      () => input,
      position: Vector2(game.size.x / 2, 140),
      boxSize: Vector2(game.size.x * 0.6, 60),
      onTap: () {
        if (!game.overlays.isActive('code_input'))
          game.overlays.add('code_input');
      },
    );
    add(inputDisplay);
  }

  Future<void> attemptJoin(String code) async {
    if (code.length != 6) {
      _showTransientMessage('Code must be 6 chars');
      return;
    }
    final matchId = 'match_$code';
    try {
      final functions = FirebaseFunctions.instanceFor(region: 'us-central1');
      final callable = functions.httpsCallable('joinMatch');
      final playerId = await GuestService.getOrCreateGuestId();
      final res = await callable.call({
        'matchId': matchId,
        'playerId': playerId,
      });
      final data = res.data as Map<String, dynamic>? ?? {};
      if (data['ok'] == true) {
        _showTransientMessage('Joined match');
        game.openMatchWithId(matchId, isCreator: false);
        removeFromParent();
        return;
      } else {
        final msg = data['message'] as String? ?? 'Unable to join';
        _showTransientMessage(msg);
        return;
      }
    } catch (e) {
      debugPrint('joinMatch callable error: $e');
      _showTransientMessage('Failed to join. Try again.');
    }
  }

  void _showTransientMessage(String text, {int ms = 900}) {
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

class _InputDisplay extends PositionComponent with TapCallbacks {
  final String Function() getter;
  final void Function()? onTap;
  _InputDisplay(
    this.getter, {
    required Vector2 position,
    Vector2? boxSize,
    this.onTap,
  }) : super(
         position: position,
         size: boxSize ?? Vector2(160, 60),
         anchor: Anchor.center,
       );

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

    // (Return button and screen label are added by the parent screen.)
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

class _ReturnButton extends SpriteComponent with TapCallbacks {
  final VoidCallback onPressed;
  _ReturnButton({
    required Sprite sprite,
    required Vector2 position,
    required this.onPressed,
  }) : super(
         sprite: sprite,
         size: Vector2(50, 50),
         position: position,
         anchor: Anchor.topLeft,
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
