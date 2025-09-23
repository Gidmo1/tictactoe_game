import 'user.dart';

class Match {
  final String id; // Firestore document ID
  final List<String> board; // 9 cells: '', 'X', 'O'
  final User playerX; // Player using X
  final User playerO; // Player using O
  String currentTurnUserId; // Who’s turn it is
  String? winnerId; // Winner's userId or null
  final bool isDraw;

  Match({
    required this.id,
    required this.board,
    required this.playerX,
    required this.playerO,
    required this.currentTurnUserId,
    this.winnerId,
    this.isDraw = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'board': board,
      'playerX': playerX.toJson(),
      'playerO': playerO.toJson(),
      'currentTurnUserId': currentTurnUserId,
      'winnerId': winnerId,
      'isDraw': isDraw,
    };
  }

  static Match fromJson(String id, Map<String, dynamic> json) {
    return Match(
      id: id,
      board: List<String>.from(json['board']),
      playerX: User.fromJson(Map<String, dynamic>.from(json['playerX'])),
      playerO: User.fromJson(Map<String, dynamic>.from(json['playerO'])),
      currentTurnUserId: json['currentTurnUserId'],
      winnerId: json['winnerId'],
      isDraw: json['isDraw'] ?? false,
    );
  }
}
