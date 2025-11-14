import 'package:flutter/foundation.dart';
import 'package:tictactoe_game/tictactoe.dart';
import '../service/invite_service.dart';

class LinkHandler {
  static TicTacToeGame? _gameInstance;
  static bool _isInitialized = false;

  // Initialize the link handler with the running TicTacToeGame instance
  // This listens for incoming links and handles cold-start invites
  static Future<void> initialize(TicTacToeGame game) async {
    if (_isInitialized) return; // Prevent double initialization
    _isInitialized = true;
    _gameInstance = game;

    //firstly, app launched via deep link
    try {
      final initialMatchId = await InviteService.getInitialInvite();
      if (initialMatchId != null) {
        debugPrint(' Cold start with matchId: $initialMatchId');
        _navigateToMatch(initialMatchId, isCreator: false);
      }
    } catch (e) {
      debugPrint(' Error during cold-start link handling: $e');
    }

    // secondly, Listen for incoming deep links
    InviteService.listenForInvites((String matchId) {
      debugPrint(' Deep link received while app is running: $matchId');
      _navigateToMatch(matchId, isCreator: false);
    });
  }

  // Clean up and stop listening for deep links
  static void dispose() {
    InviteService.dispose();
    _isInitialized = false;
    _gameInstance = null;
  }

  // Navigate the player to the match inside the game
  static void _navigateToMatch(String matchId, {required bool isCreator}) {
    if (_gameInstance == null) {
      debugPrint(' Game instance not set, cannot navigate to match.');
      return;
    }

    try {
      debugPrint(' Navigating to match: $matchId');
      _gameInstance!.openMatchWithId(matchId, isCreator: isCreator);
    } catch (e) {
      debugPrint(' Failed to navigate to match: $e');
    }
  }
}
