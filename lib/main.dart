import 'package:flutter/material.dart';
import 'package:flame/game.dart';
import 'package:flame_audio/flame_audio.dart';
import 'tictactoe.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Preload audio
  await FlameAudio.audioCache.loadAll(['tap.wav', 'win.wav', 'lose.wav']);

  runApp(GameWidget(game: TicTacToeGame()));
}
