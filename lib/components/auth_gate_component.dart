import 'dart:ui';
import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flame/events.dart';
import 'package:flame/palette.dart';
import 'package:flutter/material.dart' as material;
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:tictactoe_game/tictactoe.dart';

typedef OnSignedIn = void Function();

class AuthGateComponent extends PositionComponent
    with TapCallbacks, HasGameReference<TicTacToeGame> {
  final OnSignedIn? onSignedIn;
  final bool nonDismissible;

  late SpriteComponent _modal;
  late TextComponent _title;
  late _TapButton _fbButton;

  AuthGateComponent({this.onSignedIn, this.nonDismissible = false});

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    // Fullscreen
    size = game.size.clone();
    anchor = Anchor.topLeft;

    final modalW = game.size.x * 0.8;
    final modalH = game.size.y * 0.48;
    final modalCenter = Vector2(game.size.x / 2, game.size.y / 2);

    final overlaySprite = await game.loadSprite('confirmation_overlay.png');
    _modal = SpriteComponent(
      sprite: overlaySprite,
      size: Vector2(modalW, modalH),
      anchor: Anchor.center,
    )..position = modalCenter;

    final bg = RectangleComponent(
      size: Vector2(modalW, modalH),
      position: modalCenter,
      anchor: Anchor.center,
      paint: Paint()..color = const Color.fromARGB(240, 18, 18, 18),
    );
    add(bg);

    // Light drop shadow
    add(
      RectangleComponent(
        size: Vector2(modalW + 6, modalH + 6),
        position: modalCenter + Vector2(3, 4),
        anchor: Anchor.center,
        paint: Paint()..color = const Color.fromARGB(40, 0, 0, 0),
      ),
    );

    // Accent sprite on top of the background
    final spriteAccent = SpriteComponent(
      sprite: overlaySprite,
      size: Vector2(modalW * 0.92, modalH * 0.36),
      position: modalCenter - Vector2(0, modalH / 2 - (modalH * 0.18) - 6),
      anchor: Anchor.center,
    );
    add(spriteAccent);

    _title = TextComponent(
      text: 'Sign in so you won\'t lose your progress',
      textRenderer: TextPaint(
        style: const material.TextStyle(
          color: material.Colors.white,
          fontSize: 18,
          fontWeight: material.FontWeight.bold,
        ),
      ),
    )..anchor = Anchor.topCenter;
    _title.position = Vector2(modalCenter.x, modalCenter.y - modalH / 2 + 20);
    add(_title);

    final btnW = modalW * 0.82;
    final btnH = 56.0; // slightly larger buttons for better tap targets
    final gap = 12.0;

    _fbButton = _TapButton(
      size: Vector2(btnW, btnH),
      position: modalCenter + Vector2(0, -btnH - gap / 2),
      paint: BasicPalette.blue.withAlpha(220).paint(),
      icon: FontAwesomeIcons.facebookF,
      label: 'Continue with Facebook',
      onPressed: _onFacebookPressed,
    );

    add(_fbButton);

    // entrance animation
    // entrance animation for modal background and accent
    bg.scale = Vector2.all(0.7);
    bg.add(
      ScaleEffect.to(
        Vector2.all(1.0),
        EffectController(duration: 0.18, curve: material.Curves.easeOutBack),
      ),
    );
    spriteAccent.scale = Vector2.all(0.7);
    spriteAccent.add(
      ScaleEffect.to(
        Vector2.all(1.0),
        EffectController(duration: 0.20, curve: material.Curves.easeOutBack),
      ),
    );
  }

  @override
  void render(Canvas canvas) {
    final scrim = Paint()..color = const Color.fromARGB(140, 0, 0, 0);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.x, size.y), scrim);
    super.render(canvas);
  }

  @override
  void onTapDown(TapDownEvent event) {
    final local = event.localPosition;
    final modalW = game.size.x * 0.8;
    final modalH = game.size.y * 0.48;
    final left = (size.x - modalW) / 2;
    final top = (size.y - modalH) / 2;
    final r = Rect.fromLTWH(left, top, modalW, modalH);
    if (!r.contains(Offset(local.x, local.y)) && !nonDismissible) _close();
  }

  Future<void> _onFacebookPressed() async {
    _feedbackEffect(_fbButton);
    try {
      final helper = (game as dynamic).authHelper;
      if (helper != null && helper.signInWithFacebook != null)
        await helper.signInWithFacebook();
    } catch (e) {
      if (kDebugMode) print('AuthGate fb helper error: $e');
    }
    _close(notify: true);
  }

  void _feedbackEffect(PositionComponent c) {
    c.add(
      ScaleEffect.by(
        Vector2.all(0.06),
        EffectController(duration: 0.06, reverseDuration: 0.06),
      ),
    );
  }

  void _close({bool notify = false}) {
    _modal.add(
      ScaleEffect.to(
          Vector2.all(0.6),
          EffectController(duration: 0.12, curve: material.Curves.easeIn),
        )
        ..onComplete = () {
          removeFromParent();
          if (notify && onSignedIn != null) onSignedIn!();
        },
    );
  }
}

class _TapButton extends PositionComponent with TapCallbacks {
  final Paint paint;
  final String label;
  final material.IconData icon;
  final Future<void> Function() onPressed;

  _TapButton({
    required Vector2 size,
    required Vector2 position,
    required this.paint,
    required this.icon,
    required this.label,
    required this.onPressed,
  }) : super(size: size, position: position, anchor: Anchor.center);

  @override
  void render(Canvas canvas) {
    final rect =
        Offset(position.x - size.x / 2, position.y - size.y / 2) &
        Size(size.x, size.y);
    final r = RRect.fromRectAndRadius(rect, const Radius.circular(10));
    canvas.drawRRect(r, paint);

    final iconPainter = material.TextPainter(
      text: material.TextSpan(
        text: String.fromCharCode(icon.codePoint),
        style: material.TextStyle(
          fontFamily: icon.fontFamily,
          package: icon.fontPackage,
          fontSize: 18,
          color: material.Colors.white,
        ),
      ),
      textDirection: material.TextDirection.ltr,
    )..layout();

    final labelPainter = material.TextPainter(
      text: material.TextSpan(
        text: label,
        style: const material.TextStyle(
          color: material.Colors.white,
          fontSize: 16,
        ),
      ),
      textDirection: material.TextDirection.ltr,
    )..layout(maxWidth: size.x - 64);

    final iconOffset = Offset(
      position.x - size.x / 2 + 14,
      position.y - iconPainter.height / 2 - 1,
    );
    iconPainter.paint(canvas, iconOffset);

    final labelOffset = Offset(
      position.x - size.x / 2 + 48,
      position.y - labelPainter.height / 2 - 1,
    );
    labelPainter.paint(canvas, labelOffset);
  }

  @override
  bool containsPoint(Vector2 point) {
    final left = position.x - size.x / 2;
    final top = position.y - size.y / 2;
    return Rect.fromLTWH(
      left,
      top,
      size.x,
      size.y,
    ).contains(Offset(point.x, point.y));
  }

  @override
  void onTapDown(TapDownEvent event) {
    onPressed();
  }
}
