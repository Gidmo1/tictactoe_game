import 'package:flame/components.dart';
import 'package:flutter/material.dart' hide Route;
import 'package:tictactoe_game/tictactoe.dart';
import 'package:tictactoe_game/board.dart';
import 'package:tictactoe_game/board_layout.dart';
import 'package:tictactoe_game/game_themes/theme_store.dart';
import 'package:tictactoe_game/service/tournament_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class TournamentBoardScreen extends Component with HasGameReference<TicTacToeGame> {
  late BoardLayout layout;
  late TournamentService tournamentService;
  
  String? tournamentId;
  String? matchId;
  String? userUid;

  @override
  Future<void> onLoad() async {
    final gameRef = findGame()!;
    final canvasSize = gameRef.size;
    layout = BoardLayout(canvasSize);
    tournamentService = TournamentService();

    // Get tournament match data
    final matchData = (gameRef as dynamic).tournamentMatchData as Map<String, dynamic>?;
    tournamentId = matchData?['tournamentId'] as String?;
    matchId = matchData?['matchId'] as String?;
    userUid = Supabase.instance.client.auth.currentUser?.id;

    // Background
    add(
      RectangleComponent(
        size: canvasSize,
        paint: Paint()..color = ThemeStore.current.boardBackground,
        priority: -1,
      ),
    );

    // Create the game board component
    add(TicTacToeBoard());

    // Hook into end match event when game ends
    // TODO: Wire match completion when board game ends
  }
}
