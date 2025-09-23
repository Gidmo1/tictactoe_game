import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/match.dart';

class GameService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Make a move on the board
  Future makeMove(String matchId, int index, String playerId) async {
    var matchDoc = _firestore.collection('matches').doc(matchId);
    var data = await matchDoc.get();
    if (!data.exists) return;

    var match = Match.fromJson(matchDoc.id, data.data()!);

    // Already filled
    if (match.board[index] != '') return;

    // Not this player's turn
    if (match.currentTurnUserId != playerId) return;

    // Set move
    match.board[index] = playerId == match.playerX.id ? 'X' : 'O';

    // Switch turn
    match.currentTurnUserId = match.currentTurnUserId == match.playerX.id
        ? match.playerO.id
        : match.playerX.id;

    // Check winner
    match.winnerId = checkWinner(match.board, match);

    await matchDoc.update(match.toJson());
  }

  /// Check winner: returns winnerId, 'draw', or null
  String? checkWinner(List<String> board, Match match) {
    var lines = [
      [0, 1, 2],
      [3, 4, 5],
      [6, 7, 8],
      [0, 3, 6],
      [1, 4, 7],
      [2, 5, 8],
      [0, 4, 8],
      [2, 4, 6],
    ];

    for (var line in lines) {
      var a = line[0], b = line[1], c = line[2];
      if (board[a] != '' && board[a] == board[b] && board[a] == board[c]) {
        return board[a] == 'X' ? match.playerX.id : match.playerO.id;
      }
    }

    // Draw
    if (!board.contains('')) return 'draw';

    return null; // no winner yet
  }

  /// Listen to real-time updates of a match
  Stream<Match> listenToMatch(String matchId) {
    return _firestore
        .collection('matches')
        .doc(matchId)
        .snapshots()
        .map((snapshot) => Match.fromJson(snapshot.id, snapshot.data()!));
  }
}
