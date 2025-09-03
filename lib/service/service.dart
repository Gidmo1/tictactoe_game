import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user.dart';

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
