import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user.dart';
import '../models/score.dart';

class UserService {
  final CollectionReference _usersCollection = FirebaseFirestore.instance
      .collection('Users');

  Future<void> saveUser(User user) async {
    return await _usersCollection.doc(user.id).set(user.toJson());
  }

  Future<User?> getUser(String userId) async {
    final doc = await _usersCollection.doc(userId).get();
    if (doc.exists) {
      return User.fromJson(doc.data() as Map<String, dynamic>);
    }
    return null;
  }
}

class ScoreService {
  final CollectionReference _scoresCollection = FirebaseFirestore.instance
      .collection('scores');

  Future<void> updateScore(Score score) async {
    final docRef = _scoresCollection.doc(score.playerId);

    await FirebaseFirestore.instance.runTransaction((transaction) async {
      final snapshot = await transaction.get(docRef);

      if (!snapshot.exists) {
        transaction.set(docRef, score.toJson());
      } else {
        final data = snapshot.data() as Map<String, dynamic>;
        final existing = Score.fromJson(data);

        final updated = Score(
          playerId: score.playerId,
          playerName: score.playerName,
          wins: existing.wins + score.wins,
          losses: existing.losses + score.losses,
          draws: existing.draws + score.draws,
          points: existing.points + score.points,
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
