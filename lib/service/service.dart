import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../models/user.dart';
import '../models/score.dart';

class UserService {
  final CollectionReference _usersCollection = FirebaseFirestore.instance
      .collection('Users');

  Future<void> saveUser(User user) async {
    // Save/update profile via server callable to prevent client-side writes.
    try {
      final callable = FirebaseFunctions.instanceFor(
        region: 'us-central1',
      ).httpsCallable('saveUserProfile');
      await callable.call({'userId': user.id, 'profile': user.toJson()});
    } catch (e) {
      // Do not write to Firestore from the client.
      rethrow;
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
    // Use server callable to update scores.
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
      // Do not write scores from the client; surface error so caller can retry.
      rethrow;
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
