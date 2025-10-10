import 'package:flutter/material.dart';
import 'package:flame_audio/flame_audio.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:flame/game.dart';
import 'tictactoe.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  //To load game audio while the game is loading
  await FlameAudio.audioCache.loadAll(['tap.wav', 'win.wav', 'lose.wav']);
  await FlameAudio.audioCache.loadAll([
    'tap.wav',
    'win.wav',
    'lose.wav',
    'button.wav',
  ]);

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TicTacToe Game',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: GameWidget(
        game: TicTacToeGame(),
        overlayBuilderMap: {
          'confirmation': (context, game) {
            final msg = (game as TicTacToeGame?)?.lastMessage ?? '';
            final username = (game as TicTacToeGame?)?.loggedInUser ?? '';
            if (msg.isEmpty || username.isEmpty) return const SizedBox.shrink();
            return Semantics(
              label: 'Login confirmation',
              child: Align(
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
                        Icon(
                          Icons.check_circle,
                          color: Colors.green,
                          size: 28,
                          semanticLabel: 'Success',
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
                            overflow: TextOverflow.visible,
                            softWrap: true,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
          'loading': (context, game) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.white),
            );
          },
          'message': (context, game) {
            final msg = (game as TicTacToeGame?)?.lastMessage ?? '';
            if (msg.isEmpty) return const SizedBox.shrink();
            // Friendly error message
            final friendlyMsg = msg.contains('network')
                ? 'Network error. Please check your connection.'
                : msg.contains('Facebook login failed')
                ? 'Facebook login failed. Try again.'
                : msg;
            return Semantics(
              label: 'Error message',
              child: Align(
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
                        Icon(
                          Icons.error,
                          color: Colors.red,
                          size: 28,
                          semanticLabel: 'Error',
                        ),
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
                            overflow: TextOverflow.visible,
                            softWrap: true,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        },
      ),
    );
  }
}
