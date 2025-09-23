import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/score.dart';

class ScoreService {
  final CollectionReference _scoresCollection = FirebaseFirestore.instance
      .collection('Scores');

  Future<void> updateScore(Score score) async {
    final docRef = _scoresCollection.doc(score.playerId);

    await FirebaseFirestore.instance.runTransaction((transaction) async {
      final snapshot = await transaction.get(docRef);

      if (!snapshot.exists) {
        // create a new score entry
        transaction.set(docRef, score.toJson());
      } else {
        // update existing totals
        final data = snapshot.data() as Map<String, dynamic>;
        final existing = Score.fromJson(data);

        final updated = Score(
          playerId: score.playerId,
          playerName: score.playerName,
          wins: existing.wins + score.wins,
          losses: existing.losses + score.losses,
          draws: existing.draws + score.draws,
        );

        transaction.update(docRef, updated.toJson());
      }
    });
  }

  Future<Score?> getScore(String playerId) async {
    final doc = await _scoresCollection.doc(playerId).get();
    if (doc.exists) {
      return Score.fromJson(doc.data() as Map<String, dynamic>);
    }
    return null;
  }
}
