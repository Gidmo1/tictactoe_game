import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../models/user.dart';
import '../models/score.dart';

class UserService {
  final CollectionReference _usersCollection = FirebaseFirestore.instance
      .collection('Users');

  Future<void> saveUser(User user) async {
    // Use a server-side callable to save/update profile to avoid client-side
    // authoritative writes that could be abused.
    try {
      final callable = FirebaseFunctions.instanceFor(
        region: 'us-central1',
      ).httpsCallable('saveUserProfile');
      await callable.call({'userId': user.id, 'profile': user.toJson()});
    } catch (e) {
      // Fallback to local write if callable fails (preserve previous behavior),
      // but prefer server authoritative writes.
      await _usersCollection.doc(user.id).set(user.toJson());
    }
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
    // Delegate score updates to the server callable to avoid client-side
    // manipulation of score documents.
    try {
      final callable = FirebaseFunctions.instanceFor(
        region: 'us-central1',
      ).httpsCallable('updateScore');
      await callable.call({
        'playerId': score.playerId,
        'result': score.wins > 0 ? 'win' : (score.draws > 0 ? 'draw' : 'loss'),
      });
      return;
    } catch (e) {
      // If the callable fails, optionally fallback to local transaction to
      // avoid data loss, but prefer the server path.
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
      return;
    }
  }

  Future<Score?> getScore(String playerId) async {
    final doc = await _scoresCollection.doc(playerId).get();
    if (doc.exists) {
      return Score.fromJson(doc.data() as Map<String, dynamic>);
    }
    return null;
  }
}
