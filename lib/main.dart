import 'dart:async' as async;

import 'package:flutter/material.dart';
import 'package:flame_audio/flame_audio.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flame/game.dart';
import 'package:flame/components.dart';
import 'components/auth_gate_component.dart';
import 'auth_gate.dart';
import 'tictactoe.dart';
import 'service/link_service.dart';
import 'service/supabase_match_service.dart';
import 'settings_screen.dart';
import 'package:flame/flame.dart';
import 'package:tictactoe_game/game_themes/theme_store.dart';
import 'service/auth_service.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'overlays/edit_profile.dart';
import 'supabase.dart';

const inviteCodeLength = 8;

void _startProviderSignIn(
  BuildContext context,
  TicTacToeGame game,
  Future<dynamic> Function() action,
) {
  async.StreamSubscription<AuthState>? subscription;
  subscription = Supabase.instance.client.auth.onAuthStateChange.listen((state) {
    if (state.event != AuthChangeEvent.signedIn) return;
    game.pendingAuthOnSignedIn?.call();
    game.pendingAuthOnSignedIn = null;
    subscription?.cancel();
    game.overlays.remove('auth_gate');
  });
  action().catchError((_) => game.overlays.remove('auth_gate'));
  Future.delayed(const Duration(seconds: 20), () {
    subscription?.cancel();
    game.overlays.remove('auth_gate');
  });
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeSupabase();
  await Flame.device.fullScreen();
  await Flame.device.setPortraitUpOnly();

  await FlameAudio.audioCache.loadAll([
    'tap.wav',
    'win.wav',
    'lose.wav',
    'button.wav',
    'background_music.mp3',
  ]);
  await ThemeStore.init();
  runApp(const MyApp());
}

/// A quick Flutter-drawn "match connection" loading panel that appears the
/// instant the user enters the online tournament match flow (before the Flame
/// screen has finished loading sprites / talking to the backend). It cycles
/// friendly status messages so users never stare at a blank/black screen, and
/// is removed by the match screen itself once its content is ready.
class _MatchConnectionFallback extends StatefulWidget {
  final Color backgroundColor;
  final Color panelColor;
  final Color contrastColor;
  final Color accentColor;

  const _MatchConnectionFallback({
    required this.backgroundColor,
    required this.panelColor,
    required this.contrastColor,
    required this.accentColor,
  });

  @override
  State<_MatchConnectionFallback> createState() =>
      _MatchConnectionFallbackState();
}

class _MatchConnectionFallbackState extends State<_MatchConnectionFallback> {
  static const _statusMessages = [
    'CONNECTING TO PLAYER...',
    'BUILDING SPRITES AND BUTTONS...',
    'SYNCING MATCH BOARD...',
    'WAITING FOR OPPONENT...',
    'ALMOST THERE...',
  ];

  int _messageIndex = 0;
  async.Timer? _messageTimer;

  @override
  void initState() {
    super.initState();
    _messageTimer = async.Timer.periodic(const Duration(milliseconds: 900), (_) {
      if (!mounted) return;
      setState(() {
        _messageIndex = (_messageIndex + 1) % _statusMessages.length;
      });
    });
  }

  @override
  void dispose() {
    _messageTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: widget.backgroundColor,
      child: Center(
        child: Container(
          width: 320,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 30),
          decoration: BoxDecoration(
            color: widget.panelColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: widget.accentColor.withValues(alpha: 0.6),
              width: 1.5,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'MATCH CONNECTION',
                style: TextStyle(
                  color: widget.contrastColor,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 22),
              const SizedBox(
                width: 26,
                height: 26,
                child: CircularProgressIndicator(strokeWidth: 3),
              ),
              const SizedBox(height: 20),
              Text(
                _statusMessages[_messageIndex],
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: widget.contrastColor,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class DeepLinkHandler extends StatefulWidget {
  const DeepLinkHandler({super.key});

  @override
  State<DeepLinkHandler> createState() => _DeepLinkHandlerState();
}

class _CodeInputOverlay extends StatefulWidget {
  final TicTacToeGame game;
  const _CodeInputOverlay({required this.game});

  @override
  State<_CodeInputOverlay> createState() => _CodeInputOverlayState();
}

class _CodeInputOverlayState extends State<_CodeInputOverlay> {
  final _controller = TextEditingController();
  String? _notice;
  bool _busy = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeStore.current;
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 360),
        padding: const EdgeInsets.fromLTRB(22, 20, 22, 16),
        decoration: BoxDecoration(
          color: theme.boardBackground,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: theme.gridColor.withValues(alpha: 0.6)),
          boxShadow: const [
            BoxShadow(color: Colors.black54, blurRadius: 18, offset: Offset(0, 8)),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'ENTER CODE',
              style: TextStyle(
                color: theme.contrastColor,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _controller,
              autofocus: true,
              maxLength: inviteCodeLength,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp('[A-Z0-9]')),
              ],
              decoration: const InputDecoration(
                filled: true,
                fillColor: Colors.white12,
                counterText: '',
                hintText: 'MATCH CODE',
                hintStyle: TextStyle(color: Colors.white54),
                border: OutlineInputBorder(),
              ),
              style: const TextStyle(color: Colors.white, letterSpacing: 3),
              onSubmitted: (_) => _tryJoin(),
            ),
            if (_notice != null)
              Text(_notice!, style: const TextStyle(color: Colors.orange)),
            const SizedBox(height: 12),
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: theme.textColor,
                backgroundColor: theme.buttonBase,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              ),
              onPressed: _busy ? null : _tryJoin,
              child: _busy
                  ? const CircularProgressIndicator()
                  : const Text('ENTER MATCH'),
            ),
            TextButton(
              onPressed: () => widget.game.overlays.remove('code_input'),
              child: const Text('CANCEL'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _tryJoin() async {
    if (!await widget.game.requireSignedInForOnlineAction()) {
      return;
    }

    final matchId = _controller.text.trim().toUpperCase();
    if (matchId.isEmpty) {
      setState(() => _notice = 'Please enter a match code');
      return;
    }
    setState(() => _busy = true);
    try {
      final match = await SupabaseMatchService().joinMatch(matchId: matchId);
      final joinedId = match['id']?.toString();
      if (joinedId == null || joinedId.isEmpty) {
        setState(() => _notice = 'Match unavailable or already joined');
        return;
      }
      widget.game.openMatchWithId(joinedId, isCreator: false);
      widget.game.overlays.remove('code_input');
    } catch (_) {
      setState(() => _notice = 'Server error. Tap Join to try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

}

class _TournamentInputOverlay extends StatefulWidget {
  final String title;
  final String initialValue;
  final String hintText;
  final int maxLength;
  final bool allowUppercase;
  final void Function(String) onSubmit;

  const _TournamentInputOverlay({
    required this.title,
    required this.initialValue,
    required this.hintText,
    required this.maxLength,
    required this.allowUppercase,
    required this.onSubmit,
  });

  @override
  State<_TournamentInputOverlay> createState() => _TournamentInputOverlayState();
}

class _TournamentInputOverlayState extends State<_TournamentInputOverlay> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeStore.current;
    return Container(
      constraints: const BoxConstraints(maxWidth: 360),
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 16),
      decoration: BoxDecoration(
        color: theme.boardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.gridColor.withValues(alpha: 0.6)),
        boxShadow: const [
          BoxShadow(color: Colors.black54, blurRadius: 18, offset: Offset(0, 8)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            widget.title,
            style: TextStyle(
              color: theme.contrastColor,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            autofocus: true,
            maxLength: widget.maxLength,
            textCapitalization: widget.allowUppercase
                ? TextCapitalization.characters
                : TextCapitalization.sentences,
            inputFormatters: [
              if (widget.allowUppercase)
                FilteringTextInputFormatter.allow(RegExp('[A-Z0-9]'))
              else
                LengthLimitingTextInputFormatter(widget.maxLength),
            ],
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.white12,
              counterText: '',
              hintText: widget.hintText,
              hintStyle: const TextStyle(color: Colors.white54),
              border: const OutlineInputBorder(),
            ),
            style: const TextStyle(color: Colors.white, letterSpacing: 2),
            onSubmitted: (value) {
              final finalValue = widget.allowUppercase
                  ? value.trim().toUpperCase()
                  : value.trim();
              widget.onSubmit(finalValue);
            },
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextButton(
                style: TextButton.styleFrom(
                  foregroundColor: theme.textColor,
                  backgroundColor: theme.buttonBase,
                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
                ),
                onPressed: () {
                  final value = widget.allowUppercase
                      ? _controller.text.trim().toUpperCase()
                      : _controller.text.trim();
                  widget.onSubmit(value);
                },
                child: const Text('SAVE'),
              ),
              const SizedBox(width: 10),
              TextButton(
                onPressed: () {
                  if (widget.allowUppercase) {
                    widget.onSubmit(widget.initialValue);
                  } else {
                    widget.onSubmit(widget.initialValue);
                  }
                },
                child: const Text('CANCEL'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tic Tac Toe',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        scaffoldBackgroundColor: Colors.black,
        brightness: Brightness.dark,
      ),
      home: const DeepLinkHandler(),
    );
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
      backgroundBuilder: (context) =>
          const ColoredBox(color: Color(0xFF10141F)),
      loadingBuilder: (context) => const ColoredBox(
        color: Color(0xFF10141F),
        child: Center(
          child: CircularProgressIndicator(color: Color(0xFFD4AF37)),
        ),
      ),
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
        'tournament_name_input': (context, game) {
          final g = game as TicTacToeGame;
          return Material(
            color: Colors.transparent,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: _TournamentInputOverlay(
                  title: 'TOURNAMENT NAME',
                  initialValue: g.pendingTournamentName,
                  hintText: 'ENTER NAME',
                  maxLength: 24,
                  allowUppercase: false,
                  onSubmit: (value) {
                    g.onTournamentNameSubmitted?.call(value);
                    g.overlays.remove('tournament_name_input');
                  },
                ),
              ),
            ),
          );
        },
        'tournament_code_input': (context, game) {
          final g = game as TicTacToeGame;
          return Material(
            color: Colors.transparent,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: _TournamentInputOverlay(
                  title: 'INVITE CODE',
                  initialValue: g.pendingTournamentInviteCode,
                  hintText: 'ABC123',
                  maxLength: 6,
                  allowUppercase: true,
                  onSubmit: (value) {
                    g.onTournamentInviteSubmitted?.call(value);
                    g.overlays.remove('tournament_code_input');
                  },
                ),
              ),
            ),
          );
        },

        // Message overlay
        'message': (context, game) {
          final msg = (game as TicTacToeGame?)?.lastMessage ?? '';

          final friendlyMsg = msg.contains('network')
              ? 'Network error. Please check your connection.'
              : msg.contains('login failed')
              ? 'Login failed. Try again.'
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

        // Competition fallback overlay: a quick Flutter-drawn background that
        // appears immediately when navigating to the Competition screen so
        // users never see a black frame while Flame loads sprites.
        'competition_fallback': (context, game) {
          return Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/images/background.png'),
                fit: BoxFit.cover,
              ),
            ),
          );
        },
        // Match connection fallback: shown instantly when entering the online
        // tournament match flow (tournament_match_play or a tournament invite)
        // so users never see a black screen while Flame + network requests are
        // loading. The match screen removes it once its content is ready.
        'match_loading_fallback': (context, game) {
          final theme = ThemeStore.current;
          return _MatchConnectionFallback(
            backgroundColor: theme.boardBackground,
            panelColor: theme.buttonBase,
            contrastColor: theme.contrastColor,
            accentColor: theme.gridColor,
          );
        },
        // Edit profile / avatar claim overlay: invoked after first completed game
        'edit_profile': (context, game) {
          final g = game as TicTacToeGame;
          return Material(
            color: Colors.transparent,
            child: Center(
              child: EditProfileOverlay(game: g, navigateToProfile: true),
            ),
          );
        },
        'edit_profile_inline': (context, game) {
          final g = game as TicTacToeGame;
          return Material(
            color: Colors.transparent,
            child: Center(
              child: EditProfileOverlay(
                game: g,
                navigateToProfile: false,
                showAvatars: false,
              ),
            ),
          );
        },
        // Claim avatar overlay: shown when a new player returns home after
        // completing their first match. This presents avatar choices only
        // and does not navigate to the profile screen after saving.
        'claim_avatar': (context, game) {
          final g = game as TicTacToeGame;
          return Material(
            color: Colors.transparent,
            child: Center(
              child: EditProfileOverlay(
                game: g,
                navigateToProfile: false,
                showAvatars: true,
              ),
            ),
          );
        },
        // Current Supabase auth UI.
        'auth_gate': (context, game) {
          return GameAuthOverlay(game: game as TicTacToeGame);
        },
        // Legacy auth overlay retained only for compatibility.
        'auth_gate_legacy': (context, game) {
          final g = game as TicTacToeGame;
          // Remove any Flame AuthGateComponent so the Flutter overlay isn't stacked
          try {
            final existing = List<Component>.from(
              g.children.whereType<AuthGateComponent>(),
            );
            for (final e in existing) {
              try {
                e.removeFromParent();
              } catch (_) {}
            }
          } catch (_) {}
          return Material(
            color: Colors.transparent,
            child: Center(
              child: Container(
                width: MediaQuery.of(context).size.width * 0.84,
                height: MediaQuery.of(context).size.height * 0.60,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  image: const DecorationImage(
                    image: AssetImage('assets/images/confirmation_overlay.png'),
                    fit: BoxFit.contain,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 36),
                    const Text(
                      'Sign in so you don\'t lose your progress',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 22),
                    ElevatedButton.icon(
                      onPressed: () {
                        try {
                          final helper = AuthHelper();

                          // Start the platform sign-in flow but don't await it here.
                          // Awaiting the provider flow can block the UI thread while
                          // the native broker/activity runs — instead listen for the
                          // resulting auth state change and continue when a user
                          // appears.
                          // Start the platform sign-in flow but do not await it here.
                          // Attach a then() to display a snackbar when the future
                          // completes to give immediate feedback to the user.
                          helper
                              .signInWithGoogle()
                              .then((cred) {
                                try {
                                  if (cred != null) {
                                    final name =
                                        cred.user?.displayName ?? 'Player';
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Signed in as $name'),
                                      ),
                                    );
                                  } else {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Sign-in cancelled'),
                                      ),
                                    );
                                  }
                                } catch (_) {}
                              })
                              .catchError((e) {
                                try {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Sign-in failed'),
                                    ),
                                  );
                                } catch (_) {}
                              });

                          async.StreamSubscription<AuthState>? sub;
                          sub = Supabase.instance.client.auth.onAuthStateChange.listen(
                            (state) {
                              if (state.event == AuthChangeEvent.signedIn) {
                                try {
                                  if (g.pendingAuthOnSignedIn != null) {
                                    g.pendingAuthOnSignedIn!();
                                    g.pendingAuthOnSignedIn = null;
                                  }
                                } catch (_) {}
                                try {
                                  sub?.cancel();
                                } catch (_) {}
                                try {
                                  g.overlays.remove('auth_gate');
                                } catch (_) {}
                              }
                            },
                          );

                          // Failsafe: remove overlay after timeout so the UI
                          // doesn't remain blocked indefinitely.
                          Future.delayed(const Duration(seconds: 20), () {
                            try {
                              sub?.cancel();
                            } catch (_) {}
                            try {
                              g.overlays.remove('auth_gate');
                            } catch (_) {}
                          });
                        } catch (e) {
                          try {
                            g.overlays.remove('auth_gate');
                          } catch (_) {}
                        }
                      },
                      icon: FaIcon(FontAwesomeIcons.google),
                      label: const Text('Sign in with Google'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF34A853),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.zero,
                        ),
                      ),
                    ),

                    const SizedBox(height: 10),
                    ElevatedButton.icon(
                      onPressed: () => _startProviderSignIn(
                        context,
                        g,
                        () => AuthHelper().signInWithDiscord(),
                      ),
                      icon: const FaIcon(FontAwesomeIcons.discord),
                      label: const Text('Sign in with Discord'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF5865F2),
                        foregroundColor: Colors.white,
                        shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.zero,
                        ),
                      ),
                    ),

                    const SizedBox(height: 2),
                    TextButton(
                      onPressed: () => g.overlays.remove('auth_gate'),
                      child: const Text(
                        'Maybe later',
                        style: TextStyle(color: Colors.white),
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
