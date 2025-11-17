import 'package:flutter/material.dart';
import 'package:flame_audio/flame_audio.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:flame/game.dart';
import 'tictactoe.dart';
import 'service/link_service.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'service/guest_service.dart';
import 'settings_screen.dart';
import 'package:flame/flame.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Initialize Flame and audio
  await Flame.device.fullScreen();
  await Flame.device.setPortraitUpOnly();

  await FlameAudio.audioCache.loadAll([
    'tap.wav',
    'win.wav',
    'lose.wav',
    'button.wav',
    'background_music.mp3',
  ]);

  // Preload some mostly used images for fast loading on screens
  final preloadNames = [
    'loading.png',
    'leaderboard_background.png',
    'background.png',
    'return.png',
    'joinatournament.png',
    'play.png',
    'Bronze I.png',
    'Silver II.png',
    'Gold III.png',
    'confirmation_overlay.png',
    'copy.png',
    'sharewhatsapp.png',
  ];

  Future<void> _tryLoad(String key) async {
    try {
      await Flame.images.load(key);
      debugPrint('Preloaded image: $key');
    } catch (_) {
      // ignore
    }
  }

  try {
    for (final name in preloadNames) {
      // Common variants used in projects
      await _tryLoad(name);
      await _tryLoad('images/$name');
      await _tryLoad('assets/images/$name');
      await _tryLoad('assets/$name');
    }
  } catch (_) {
    // Non-fatal if specific assets are missing; the app will fall back.
  }

  runApp(const MyApp());
}

// Invite flow UI uses Flame components; this Flutter overlay only exposes a native text field.

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TicTacToe Game',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const DeepLinkHandler(),
    );
  }
}

// Handles deep link detection and routes to the game logic
class DeepLinkHandler extends StatefulWidget {
  const DeepLinkHandler({super.key});

  @override
  State<DeepLinkHandler> createState() => _DeepLinkHandlerState();
}

class _CodeInputOverlay extends StatefulWidget {
  final TicTacToeGame game;
  const _CodeInputOverlay({Key? key, required this.game}) : super(key: key);

  @override
  State<_CodeInputOverlay> createState() => _CodeInputOverlayState();
}

class _CodeInputOverlayState extends State<_CodeInputOverlay> {
  final TextEditingController _controller = TextEditingController();
  String? _notice;
  bool _busy = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _clearGeneratedCode() {
    // best-effort: clear any generated code in the Flame game if present
    try {
      final dynamic g = widget.game;
      if (g.clearGeneratedInviteCode is Function) {
        g.clearGeneratedInviteCode();
      }
    } catch (_) {}
  }

  Future<void> _tryJoin() async {
    final matchId = _controller.text.trim().toUpperCase();
    if (matchId.isEmpty) {
      setState(() => _notice = 'Please enter a match code');
      // auto-hide notice after a short delay
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) setState(() => _notice = null);
      });
      return;
    }

    setState(() => _busy = true);
    try {
      final functions = FirebaseFunctions.instanceFor(region: 'us-central1');
      final callable = functions.httpsCallable('joinMatch');

      final payload = <String, dynamic>{'matchId': matchId};
      final fbUser = FirebaseAuth.instance.currentUser;
      if (fbUser == null) {
        final pid = await GuestService.getOrCreateGuestId();
        payload['playerId'] = pid;
      }

      final res = await callable.call(payload);
      final data = res.data as Map<String, dynamic>? ?? {};

      if (data['alreadyHasOpponent'] == true) {
        setState(() => _notice = 'Match already has an opponent');
        try {
          _clearGeneratedCode();
        } catch (_) {}
        widget.game.overlays.remove('code_input');
        return;
      }

      // success — use the game's join flow (adds Flame lobby component)
      widget.game.joinMatch(matchId);
      try {
        _clearGeneratedCode();
      } catch (_) {}
      widget.game.overlays.remove('code_input');
      return;
    } catch (err) {
      debugPrint('joinMatch callable error (single attempt): $err');
      // Show a concise error and allow user to manually retry
      setState(() => _notice = 'Server error. Tap Join to try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenW = MediaQuery.of(context).size.width;
    final w = (screenW * 0.85).clamp(300.0, 520.0);
    final rawH = w * 0.6;
    double h = rawH;
    if (h < 160) h = 160;
    if (h > 360) h = 360;
    h = h + 30;
    final screenH = MediaQuery.of(context).size.height;
    final minDesiredH = screenH * 0.44;
    if (h < minDesiredH) h = minDesiredH;
    final maxAllowedH = screenH * 0.88;
    if (h > maxAllowedH) h = maxAllowedH;

    final bg = Container(
      constraints: BoxConstraints(maxWidth: w.toDouble()),
      height: h,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
      decoration: BoxDecoration(
        image: const DecorationImage(
          image: AssetImage('assets/images/confirmation_overlay.png'),
          fit: BoxFit.contain,
          alignment: Alignment.center,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(height: h * 0.30),
          SizedBox(
            width: w * 0.4,
            height: h * 0.22,
            child: Center(
              child: TextField(
                controller: _controller,
                autofocus: true,
                maxLength: 6,
                textCapitalization: TextCapitalization.characters,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp('[A-Z2-9]')),
                ],
                decoration: const InputDecoration(
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderSide: BorderSide.none,
                    borderRadius: BorderRadius.all(Radius.circular(6)),
                  ),
                  counterText: '',
                  contentPadding: EdgeInsets.symmetric(
                    vertical: 8,
                    horizontal: 12,
                  ),
                ),
                style: const TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 3,
                  fontSize: 20,
                ),
                textAlign: TextAlign.center,
                onSubmitted: (_) => _tryJoin(),
              ),
            ),
          ),
          SizedBox(
            height: 28.0,
            child: Center(
              child: _notice != null
                  ? Text(_notice!, style: const TextStyle(color: Colors.orange))
                  : const SizedBox.shrink(),
            ),
          ),
          Padding(
            // reduce the top padding to move buttons up ~14px to avoid overflow
            padding: const EdgeInsets.only(top: 15.0),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  onTap: () {
                    try {
                      _clearGeneratedCode();
                    } catch (_) {}
                    widget.game.overlays.remove('code_input');
                  },
                  child: Image.asset(
                    'assets/images/cancel.png',
                    width: 120,
                    height: 45,
                  ),
                ),
                const SizedBox(width: 40),
                GestureDetector(
                  onTap: _busy ? null : _tryJoin,
                  child: _busy
                      ? const SizedBox(
                          width: 36,
                          height: 36,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Image.asset(
                          'assets/images/join.png',
                          width: 120,
                          height: 45,
                        ),
                ),
              ],
            ),
          ),
          SizedBox(height: h * 0.16),
        ],
      ),
    );

    return Center(child: bg);
  }
}

class _DeepLinkHandlerState extends State<DeepLinkHandler>
    with WidgetsBindingObserver {
  final _game = TicTacToeGame();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Link listening for dynamic invite links
    LinkService.startListening(context, (matchId) {
      debugPrint('Joining match from link: $matchId');
      _game.joinMatch(matchId);
    });

    // Cold start (opened from a link)
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final matchId = await LinkService.getInitialLinkIfAny();
      if (matchId != null) {
        debugPrint('App opened via link with matchId=$matchId');
        _game.joinMatch(matchId);
      }
    });
  }

  @override
  void dispose() {
    LinkService.stopListening();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Handle app pause/resume
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    try {
      if (state == AppLifecycleState.paused) {
        // Stop menu music when app is backgrounded to avoid playing in background
        _game.stopMenuMusic();
      } else if (state == AppLifecycleState.resumed) {
        // Only resume menu music if the current route should play music
        if (SettingsScreen.gameSoundOn &&
            (_game.currentRoute == 'menu' || _game.currentRoute == 'profile')) {
          _game.playMenuMusic();
        }
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return GameWidget(
      game: _game,
      overlayBuilderMap: {
        // Success login overlay
        'confirmation': (context, game) {
          final g = game as TicTacToeGame?;
          final msg = g?.lastMessage ?? '';
          final username = g?.loggedInUser ?? '';
          if (msg.isEmpty || username.isEmpty) return const SizedBox.shrink();
          return Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 32),
              child: Container(
                constraints: const BoxConstraints(maxWidth: 420),
                height: 120,
                decoration: BoxDecoration(
                  image: const DecorationImage(
                    image: AssetImage('assets/images/confirmation_overlay.png'),
                    fit: BoxFit.cover,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 10,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.check_circle,
                      color: Colors.green,
                      size: 28,
                    ),
                    const SizedBox(width: 12),
                    Flexible(
                      child: Text(
                        'Successfully logged in as $username',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          decoration: TextDecoration.none,
                          shadows: [
                            Shadow(
                              color: Colors.black,
                              blurRadius: 8,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },

        // Loading overlay
        'loading': (context, game) =>
            const Center(child: CircularProgressIndicator(color: Colors.white)),

        // Code input overlay: minimal transparent widget that exposes a
        // native TextField so the phone keyboard is shown. We keep visuals
        // in Flame and only use this tiny overlay for text input.
        'code_input': (context, game) {
          final g = game as TicTacToeGame;
          return Material(
            color: Colors.transparent,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: _CodeInputOverlay(game: g),
              ),
            ),
          );
        },

        // Message overlay
        'message': (context, game) {
          final msg = (game as TicTacToeGame?)?.lastMessage ?? '';

          final friendlyMsg = msg.contains('network')
              ? 'Network error. Please check your connection.'
              : msg.contains('Facebook login failed')
              ? 'Facebook login failed. Try again.'
              : msg;

          return Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 32),
              child: Container(
                constraints: const BoxConstraints(maxWidth: 340),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 10,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error, color: Colors.red, size: 28),
                    const SizedBox(width: 12),
                    Flexible(
                      child: Text(
                        friendlyMsg,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          decoration: TextDecoration.none,
                          shadows: [
                            Shadow(
                              color: Colors.black,
                              blurRadius: 8,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      },
    );
  }
}
