import 'dart:async' as async;
import 'dart:math';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/effects.dart';
import 'package:flame_audio/flame_audio.dart';
import 'package:flutter/material.dart' hide Route;
import 'package:flutter/services.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:tictactoe_game/settings_screen.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:io' show Platform;
import 'package:android_intent_plus/android_intent.dart';
import 'package:share_plus/share_plus.dart';
import 'tictactoe.dart';
import 'components/loading_placeholder.dart';
import 'service/guest_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class GenerateCodeScreen extends Component
    with HasGameReference<TicTacToeGame> {
  String? generatedCode;
  final List<async.StreamSubscription> _subscriptions = [];
  // Button positions. Change these to move the buttons.
  Vector2 copyButtonPos = Vector2(330, 520);
  Vector2 shareButtonPos = Vector2(330, 600);

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    // Show a placeholder immediately so the user doesn't see a black screen
    final placeholder = LoadingPlaceholder(size: game.size);
    add(placeholder);

    // Load the real background in the background and swap in when ready
    Future.microtask(() async {
      try {
        final sp = await game.loadSprite('background.png');
        final bg = SpriteComponent()
          ..sprite = sp
          ..size = game.size
          ..position = Vector2.zero()
          ..priority = 0;
        add(bg);
      } catch (e) {
        debugPrint('Failed to load background.png: $e');
      } finally {
        // remove placeholder once we've attempted to load the real BG
        try {
          placeholder.removeFromParent();
        } catch (_) {}
      }
    });

    // start the generate flow soon (can run while background loads)
    Future.microtask(() => startGenerateFlow());
  }

  Future<void> startGenerateFlow() async {
    generatedCode = null;
    final codeDisplay = _CodeDisplay(
      () => generatedCode ?? '',
      position: Vector2(game.size.x / 2, 230),
    );
    // Ensure the code display is rendered above loading placeholders
    codeDisplay.priority = 11050;
    add(codeDisplay);

    // try a few codes on the server
    const maxAttempts = 4;
    var attempts = 0;
    var createdOnServer = false;
    String? usedCode;

    while (attempts < maxAttempts && !createdOnServer) {
      attempts += 1;
      generatedCode = _randomCode();
      usedCode = generatedCode;
      final code = generatedCode!;
      try {
        final functions = FirebaseFunctions.instanceFor(region: 'us-central1');
        final callable = functions.httpsCallable('createMatch');
        final playerId = await GuestService.getOrCreateGuestId();
        final res = await callable.call({
          'matchId': 'match_$code',
          'playerId': playerId,
        });
        final data = res.data as Map<String, dynamic>? ?? {};
        if (data['alreadyHasOpponent'] == true) {
          _showTransientMessage('Code in use, trying another...');
          await Future.delayed(const Duration(milliseconds: 900));
          continue;
        }
        createdOnServer = true;
        try {
          await Clipboard.setData(ClipboardData(text: code));
        } catch (_) {}
        _showTransientMessage('Code generated and copied.');
      } catch (e) {
        debugPrint('createMatch callable error: $e');
        _showTransientMessage('Server error, retrying...');
        await Future.delayed(const Duration(milliseconds: 900));
      }
    }

    if (!createdOnServer) {
      _showTransientMessage('Failed to create invite. Try again later.');
      await Future.delayed(const Duration(milliseconds: 1500));
      children.whereType<_CodeDisplay>().toList().forEach(
        (c) => c.removeFromParent(),
      );
      return;
    }

    final matchId = 'match_${usedCode!}';
    try {
      game.pendingMatchId = matchId;
      // Respect persisted symbol rotation preference so the creator may be X or O
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

    // show the copy and share buttons
    _showInviteControls(matchId, usedCode);
  }

  void _showInviteControls(String matchId, String code) {
    final centerX = game.size.x / 2 + 125;
    final centerY = game.size.y / 2;
    copyButtonPos = Vector2(centerX, centerY + 140);
    shareButtonPos = Vector2(centerX, centerY + 220);

    final copyBtn = _ImageButton(
      spriteName: 'copy.png',
      fallbackLabel: 'Copy',
      position: copyButtonPos,
      size: Vector2(260, 70),
      onPressed: () async {
        try {
          await Clipboard.setData(ClipboardData(text: code));
          _showTransientMessage('Code copied to clipboard');
        } catch (_) {
          _showTransientMessage('Could not copy code');
        }
      },
    );

    final shareBtn = _ImageButton(
      spriteName: 'sharewhatsapp.png',
      fallbackLabel: 'Share',
      position: shareButtonPos,
      size: Vector2(260, 70),
      onPressed: () async {
        final text = 'Join my TicTacToe match with this code: $code';
        final encoded = Uri.encodeComponent(text);
        // try the WhatsApp app URI first
        final appUri = Uri.parse('whatsapp://send?text=$encoded');
        if (await canLaunchUrl(appUri)) {
          try {
            await launchUrl(appUri, mode: LaunchMode.externalApplication);
            debugPrint('Opened WhatsApp via app URI');
            _showTransientMessage('Opened WhatsApp');
            return;
          } catch (e) {
            debugPrint('Failed to open WhatsApp via app URI: $e');
            // fallthrough to other attempts
          }
        }

        // try explicit Android intent for WhatsApp on Android
        if (Platform.isAndroid) {
          final packagesToTry = ['com.whatsapp', 'com.whatsapp.w4b'];
          for (final pkg in packagesToTry) {
            try {
              final intent = AndroidIntent(
                action: 'android.intent.action.SEND',
                package: pkg,
                arguments: <String, dynamic>{'android.intent.extra.TEXT': text},
                type: 'text/plain',
              );
              await intent.launch();
              debugPrint('Launched WhatsApp via AndroidIntent, package=$pkg');
              _showTransientMessage('Opened WhatsApp');
              return;
            } catch (e) {
              debugPrint('AndroidIntent launch failed for $pkg: $e');
            }
          }
        }

        // fallback: open system share sheet
        try {
          await SharePlus.instance.share(ShareParams(text: text));
          debugPrint('Opened system share sheet');
          _showTransientMessage('Opened share sheet');
          return;
        } catch (e) {
          debugPrint('Share sheet failed: $e');
        }

        // try web fallback
        final webUri = Uri.parse('https://wa.me/?text=$encoded');
        try {
          if (await canLaunchUrl(webUri)) {
            await launchUrl(webUri, mode: LaunchMode.externalApplication);
            debugPrint('Opened web wa.me fallback');
            _showTransientMessage('Opened browser');
            return;
          }
        } catch (e) {
          debugPrint('Failed to open web fallback: $e');
        }
        // last resort: open Play Store so user can install WhatsApp
        if (Platform.isAndroid) {
          final market = Uri.parse('market://details?id=com.whatsapp');
          final playWeb = Uri.parse(
            'https://play.google.com/store/apps/details?id=com.whatsapp',
          );
          try {
            if (await canLaunchUrl(market)) {
              await launchUrl(market, mode: LaunchMode.externalApplication);
              return;
            }
          } catch (_) {}
          try {
            if (await canLaunchUrl(playWeb)) {
              await launchUrl(playWeb, mode: LaunchMode.externalApplication);
              return;
            }
          } catch (_) {}
        }
        try {
          await Clipboard.setData(ClipboardData(text: code));
          _showTransientMessage(
            'Code copied — paste into WhatsApp or any messenger',
          );
        } catch (_) {
          _showTransientMessage('Could not copy code');
        }
      },
    );

    // add buttons as children so layout is simple
    copyBtn.position = copyButtonPos;
    shareBtn.position = shareButtonPos;
    add(copyBtn);
    add(shareBtn);

    // 5 minute expiry
    Future.delayed(const Duration(minutes: 5), () async {
      try {
        final doc = await FirebaseFirestore.instance
            .collection('matches')
            .doc(matchId)
            .get();
        if (doc.exists) {
          final data = doc.data() ?? {};
          if ((data['status'] ?? 'waiting') == 'waiting') {
            final functions = FirebaseFunctions.instanceFor(
              region: 'us-central1',
            );
            final callable = functions.httpsCallable('cancelMatch');
            final playerId = await GuestService.getOrCreateGuestId();
            await callable.call({'matchId': matchId, 'playerId': playerId});
            _showTransientMessage('Invite expired');
            children.whereType<_CodeDisplay>().forEach(
              (c) => c.removeFromParent(),
            );
            // remove buttons (if still present)
            try {
              copyBtn.removeFromParent();
            } catch (_) {}
            try {
              shareBtn.removeFromParent();
            } catch (_) {}
          }
        }
      } catch (_) {}
    });

    // listen for join events
    final sub = FirebaseFirestore.instance
        .collection('matches')
        .doc(matchId)
        .snapshots()
        .listen((snap) {
          if (!snap.exists) return;
          final d = snap.data() ?? {};
          if (d['playerOUID'] != null &&
              (d['playerOUID'] as String).isNotEmpty) {
            _showJoinAcceptedOverlay(matchId);
          }
        });
    _subscriptions.add(sub);
  }

  void _showJoinAcceptedOverlay(String matchId) {
    // show a small banner so the host can accept
    final flameGame = findGame();
    if (flameGame == null) return;
    // remove any existing banners for this purpose
    flameGame.children.whereType<NotificationBanner>().forEach(
      (b) => b.removeFromParent(),
    );
    final banner = NotificationBanner(
      message: 'Friend accepted your invite — tap to join',
      onJoin: () {
        try {
          game.openMatchWithId(matchId, isCreator: true);
        } catch (e) {
          debugPrint('Error opening match from banner: $e');
        }
      },
      onExpire: () async {
        try {
          final functions = FirebaseFunctions.instanceFor(
            region: 'us-central1',
          );
          final callable = functions.httpsCallable('cancelMatch');
          final playerId = await GuestService.getOrCreateGuestId();
          await callable.call({'matchId': matchId, 'playerId': playerId});
          _showTransientMessage('Invite canceled');
          // remove local UI for this invite
          children.whereType<_CodeDisplay>().forEach(
            (c) => c.removeFromParent(),
          );
          children.whereType<_ImageButton>().forEach(
            (b) => b.removeFromParent(),
          );
        } catch (e) {
          debugPrint('cancel on banner expire failed: $e');
        }
      },
    );
    flameGame.add(banner);
  }

  @override
  void onRemove() {
    for (final s in _subscriptions) {
      try {
        s.cancel();
      } catch (_) {}
    }
    _subscriptions.clear();
    super.onRemove();
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

  String _randomCode() {
    const chars = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
    final rand = Random();
    final sb = StringBuffer();
    for (var i = 0; i < 6; i++) sb.write(chars[rand.nextInt(chars.length)]);
    return sb.toString();
  }
}

class NotificationBanner extends PositionComponent with TapCallbacks {
  final String message;
  final VoidCallback onJoin;
  final Future<void> Function()? onExpire;
  final int durationMs;
  async.Timer? _dismissTimer;

  NotificationBanner({
    required this.message,
    required this.onJoin,
    this.onExpire,
    this.durationMs = 10000,
  }) : super(
         size: Vector2(360, 80),
         anchor: Anchor.topCenter,
         position: Vector2.zero(),
         priority: 20000,
       );

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    final gameRef = findGame();
    if (gameRef != null) {
      position = Vector2(gameRef.size.x / 2, 60);
    }

    add(
      RectangleComponent(
        size: size,
        position: Vector2.zero(),
        paint: Paint()..color = Colors.black.withOpacity(0.75),
      ),
    );

    add(
      TextComponent(
        text: message,
        position: Vector2(16, size.y / 2),
        anchor: Anchor.centerLeft,
        textRenderer: TextPaint(
          style: const TextStyle(color: Colors.white, fontSize: 16),
        ),
      ),
    );

    add(
      TextComponent(
        text: 'Join',
        position: Vector2(size.x - 32, size.y / 2),
        anchor: Anchor.center,
        textRenderer: TextPaint(
          style: const TextStyle(
            color: Color(0xFF7CFC00),
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );

    // start auto-dismiss timer
    _dismissTimer = async.Timer(Duration(milliseconds: durationMs), () async {
      try {
        if (onExpire != null) await onExpire!();
      } catch (e) {
        debugPrint('NotificationBanner onExpire error: $e');
      }
      try {
        removeFromParent();
      } catch (_) {}
    });
  }

  @override
  void onTapDown(TapDownEvent event) {
    // user tapped join
    try {
      _dismissTimer?.cancel();
    } catch (_) {}
    try {
      onJoin();
    } catch (e) {
      debugPrint('NotificationBanner onJoin error: $e');
    }
    removeFromParent();
  }

  @override
  void onRemove() {
    try {
      _dismissTimer?.cancel();
    } catch (_) {}
    super.onRemove();
  }
}

class _ImageButton extends PositionComponent with TapCallbacks {
  final String spriteName;
  final String fallbackLabel;
  final VoidCallback onPressed;
  final Vector2 sizeOverride;

  _ImageButton({
    required this.spriteName,
    required this.fallbackLabel,
    required Vector2 position,
    required Vector2 size,
    required this.onPressed,
  }) : sizeOverride = size,
       super(position: position, size: size, anchor: Anchor.center);

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    try {
      final gameRef = findGame();
      Sprite? sp;
      if (gameRef != null) {
        try {
          sp = await gameRef.loadSprite(spriteName);
        } catch (_) {
          sp = null;
        }
      }
      if (sp != null) {
        add(
          SpriteComponent(
            sprite: sp,
            size: sizeOverride,
            anchor: Anchor.center,
          ),
        );
      } else {
        add(
          RectangleComponent(
            size: sizeOverride,
            anchor: Anchor.center,
            paint: Paint()..color = Colors.black.withOpacity(0.6),
          ),
        );
        add(
          TextComponent(
            text: fallbackLabel,
            anchor: Anchor.center,
            position: sizeOverride / 2,
            textRenderer: TextPaint(
              style: const TextStyle(color: Colors.white, fontSize: 14),
            ),
          ),
        );
      }
    } catch (_) {}
  }

  @override
  void onTapDown(TapDownEvent event) {
    if (SettingsScreen.buttonSoundOn) FlameAudio.play('button.wav');
    try {
      // press animation then call handler
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
      // delay so the animation is visible
      Future.delayed(const Duration(milliseconds: 150), onPressed);
    } catch (_) {}
  }
}

class _CodeDisplay extends PositionComponent {
  final String Function() getter;
  _CodeDisplay(this.getter, {required Vector2 position})
    : super(position: position, size: Vector2(240, 80), anchor: Anchor.center);

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    // darker rounded-ish background for contrast so codes are readable
    add(
      RectangleComponent(
        size: size,
        position: Vector2.zero(),
        anchor: Anchor.topLeft,
        paint: Paint()..color = Colors.black.withOpacity(0.5),
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
            fontSize: 26,
            fontWeight: FontWeight.bold,
            letterSpacing: 6,
            shadows: [
              Shadow(
                color: Colors.black54,
                offset: Offset(0, 1),
                blurRadius: 2,
              ),
            ],
          ),
        ),
      ),
    );
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
