import 'dart:ui';
import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flame/events.dart';
import 'package:flutter/material.dart' as material;
import 'package:tictactoe_game/tictactoe.dart';
import 'package:tictactoe_game/service/auth_service.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

typedef OnSignedIn = void Function();

class AuthGateComponent extends PositionComponent
    with TapCallbacks, HasGameReference<TicTacToeGame> {
  final OnSignedIn? onSignedIn;
  final bool nonDismissible;

  late SpriteComponent _modal;
  late TextComponent _title;
  // Social sign-in removed; no social sign-in button here.

  AuthGateComponent({this.onSignedIn, this.nonDismissible = false});

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    // Defensive: remove any Flutter overlay that might be present so we
    // don't end up with both a Flutter and a Flame auth UI stacked.
    try {
      game.overlays.remove('auth_gate');
    } catch (_) {}
    try {
      game.overlays.remove('edit_profile');
    } catch (_) {}
    try {
      game.overlays.remove('edit_profile_inline');
    } catch (_) {}

    // Remove any other existing AuthGateComponent instances before adding ours.
    try {
      final existing = List<AuthGateComponent>.from(
        game.children.whereType<AuthGateComponent>(),
      );
      for (final e in existing) {
        try {
          e.removeFromParent();
        } catch (_) {}
      }
    } catch (_) {}

    // Ensure high priority so the gate renders on top.
    try {
      priority = 1006000000000;
    } catch (_) {}

    // Defensive onLoad: catch any errors so the component doesn't fail silently.
    try {
      // Fullscreen
      size = game.size.clone();
      anchor = Anchor.topLeft;

      final modalW = game.size.x * 0.8;
      final modalH = game.size.y * 0.60;
      final modalCenter = Vector2(game.size.x / 2, game.size.y / 2);

      Sprite? overlaySprite;
      try {
        overlaySprite = await game.loadSprite('confirmation_overlay.png');
      } catch (e) {
        // ignore: avoid_print
        print('AuthGate: confirmation_overlay.png missing: $e');
        overlaySprite = null;
      }

      if (overlaySprite != null) {
        _modal = SpriteComponent(
          sprite: overlaySprite,
          size: Vector2(modalW, modalH),
          anchor: Anchor.center,
        )..position = modalCenter;
        add(_modal);

        // Accent sprite on top of the background
        final spriteAccent = SpriteComponent(
          sprite: overlaySprite,
          size: Vector2(modalW * 0.92, modalH * 0.36),
          position: modalCenter - Vector2(0, modalH / 2 - (modalH * 0.18) - 6),
          anchor: Anchor.center,
        );
        add(spriteAccent);

        // entrance animation for modal accent
        spriteAccent.scale = Vector2.all(0.7);
        spriteAccent.add(
          ScaleEffect.to(
            Vector2.all(1.0),
            EffectController(
              duration: 0.20,
              curve: material.Curves.easeOutBack,
            ),
          ),
        );
      } else {
        // fallback rectangular modal
        _modal = SpriteComponent()
          ..size = Vector2(modalW, modalH)
          ..position = modalCenter
          ..anchor = Anchor.center;
        final bg = RectangleComponent(
          size: Vector2(modalW, modalH),
          position: modalCenter,
          anchor: Anchor.center,
          paint: Paint()..color = const Color.fromARGB(240, 18, 18, 18),
        );
        add(bg);
        add(_modal);
      }

      final bgShadow = RectangleComponent(
        size: Vector2(modalW + 6, modalH + 6),
        position: modalCenter + Vector2(3, 4),
        anchor: Anchor.center,
        paint: Paint()..color = const Color.fromARGB(40, 0, 0, 0),
      );
      add(bgShadow);

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

      // Google Sign-in button (calls AuthHelper.signInWithGoogle)
      final btnSize = Vector2(modalW * 0.86, 56);
      final googleBtn = _TapButton(
        size: btnSize,
        position: Vector2(modalCenter.x, modalCenter.y + modalH * 0.08),
        paint: Paint()..color = const Color(0xFF4285F4),
        icon: FontAwesomeIcons.google,
        label: 'Sign in with Google',
        onPressed: () async {
          // Prefer showing the Flutter overlay (it uses FontAwesome reliably).
          try {
            game.overlays.add('auth_gate');
            // remove this flame component to avoid duplicates
            removeFromParent();
            return;
          } catch (_) {}

          // Fallback: attempt direct sign-in if Flutter overlay couldn't be shown.
          try {
            final helper = AuthHelper();
            final cred = await helper.signInWithGoogle();
            if (cred != null) {
              if (onSignedIn != null) onSignedIn!();
              _close(notify: true);
            }
          } catch (e) {
            // ignore: avoid_print
            print('AuthGate: sign-in failed: $e');
          }
        },
      );
      add(googleBtn);

      // entrance animation for modal background
      try {
        _modal.scale = Vector2.all(0.7);
        _modal.add(
          ScaleEffect.to(
            Vector2.all(1.0),
            EffectController(
              duration: 0.18,
              curve: material.Curves.easeOutBack,
            ),
          ),
        );
      } catch (_) {}

      // Immediately prefer the Flutter overlay for the sign-in UI. This
      // avoids relying on canvas icon rendering and ensures the Google
      // button (FontAwesome) is visible and interactive. After adding the
      // Flutter overlay, remove this Flame component to avoid stacking.
      try {
        game.overlays.add('auth_gate');
        removeFromParent();
      } catch (_) {}
    } catch (e) {
      // If anything unexpected happens, add a minimal fallback UI so the
      // user still sees a sign-in prompt instead of a silent failure.
      // ignore: avoid_print
      print('AuthGate:onLoad failed: $e');
      try {
        size = game.size.clone();
        anchor = Anchor.topLeft;
        final modalCenter = Vector2(game.size.x / 2, game.size.y / 2);
        final bg = RectangleComponent(
          size: Vector2(game.size.x * 0.8, game.size.y * 0.60),
          position: modalCenter,
          anchor: Anchor.center,
          paint: Paint()..color = const Color.fromARGB(240, 18, 18, 18),
        );
        add(bg);
        _title =
            TextComponent(
                text: 'Sign in (fallback)',
                textRenderer: TextPaint(
                  style: const material.TextStyle(
                    color: material.Colors.white,
                    fontSize: 16,
                  ),
                ),
              )
              ..position = modalCenter - Vector2(0, 30)
              ..anchor = Anchor.center;
        add(_title);
        final googleBtn = _TapButton(
          size: Vector2(game.size.x * 0.6, 44),
          position: modalCenter + Vector2(0, 20),
          paint: Paint()..color = const Color(0xFF4285F4),
          icon: FontAwesomeIcons.google,
          label: 'Sign in with Google',
          onPressed: () async {
            try {
              final helper = AuthHelper();
              final cred = await helper.signInWithGoogle();
              if (cred != null) {
                if (onSignedIn != null) onSignedIn!();
                _close(notify: true);
              }
            } catch (e) {
              // ignore: avoid_print
              print('AuthGate fallback sign-in failed: $e');
            }
          },
        );
        add(googleBtn);
        // Also prefer the Flutter overlay in the fallback so the stable
        // Flutter widget is used instead of the canvas fallback where
        // possible.
        try {
          game.overlays.add('auth_gate');
          removeFromParent();
        } catch (_) {}
      } catch (_) {}
    }
  }

  @override
  void render(Canvas canvas) {
    final scrim = Paint()..color = const Color.fromARGB(100, 0, 0, 0);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.x, size.y), scrim);
    super.render(canvas);
  }

  @override
  void onTapDown(TapDownEvent event) {
    final local = event.localPosition;
    final modalW = game.size.x * 0.8;
    final modalH = game.size.y * 0.60;
    final left = (size.x - modalW) / 2;
    final top = (size.y - modalH) / 2;
    final r = Rect.fromLTWH(left, top, modalW, modalH);
    if (!r.contains(Offset(local.x, local.y)) && !nonDismissible) _close();
  }

  // Social sign-in removed. Use other auth flows if needed.

  // Feedback effect removed — not used in current UI.

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
    final r = RRect.fromRectAndRadius(rect, Radius.zero);
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
