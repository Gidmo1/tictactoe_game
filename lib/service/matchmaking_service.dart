import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/match.dart';
import '../models/user.dart';

class MatchmakingService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Finds or creates a match for a user
  Future<Match> findMatch(User currentUser) async {
    // Check if a player is already waiting
    var queue = await _firestore.collection('match_queue').limit(1).get();

    if (queue.docs.isEmpty) {
      // No one waiting - add self to queue
      await _firestore.collection('match_queue').add(currentUser.toJson());
      // Wait until matched
      return waitForOpponent(currentUser.id);
    } else {
      // Someone is waiting - create match
      var opponentData = queue.docs.first.data();
      var opponent = User.fromJson(opponentData);
      await queue.docs.first.reference.delete(); // remove from queue

      // Create new match document
      var newMatchRef = await _firestore.collection('matches').add({
        'board': List.generate(9, (_) => ''),
        'playerX': opponent.toJson(),
        'playerO': currentUser.toJson(),
        'currentTurnUserId': opponent.id,
        'winnerId': null,
        'isDraw': false,
      });

      var matchData = await newMatchRef.get();
      return Match.fromJson(matchData.id, matchData.data()!);
    }
  }

  // Waits until an opponent joins and a match is created
  Future<Match> waitForOpponent(String userId) async {
    return _firestore
        .collection('matches')
        .where('playerO.id', isEqualTo: userId)
        .snapshots()
        .map((snapshot) {
          if (snapshot.docs.isNotEmpty) {
            var doc = snapshot.docs.first;
            return Match.fromJson(doc.id, doc.data());
          }
          throw Exception('Waiting for opponent...');
        })
        .first;
  }
}
