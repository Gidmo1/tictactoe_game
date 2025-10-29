import 'package:flutter/material.dart';
import 'package:flame_audio/flame_audio.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:flame/game.dart';
import 'tictactoe.dart';
import 'service/link_service.dart';
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

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TicTacToe Game',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
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
                    image: AssetImage('confirmation_overlay.png'),
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

        // Message overlay
        'message': (context, game) {
          final msg = (game as TicTacToeGame?)?.lastMessage ?? '';
          if (msg.isEmpty) return const SizedBox.shrink();

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
