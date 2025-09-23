import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;

class User {
  final String id;
  final String userName;
  final String providerName;
  final String providerId;

  User({
    required this.id,
    required this.userName,
    required this.providerId,
    required this.providerName,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userName': userName,
      'providerId': providerId,
      'providerName': providerName,
    };
  }

  static User fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'],
      userName: json['userName'],
      providerId: json['providerId'],
      providerName: json['providerName'],
    );
  }

  factory User.fromFirebase(firebase_auth.User fbUser) {
    return User(
      id: fbUser.uid,
      userName: fbUser.displayName ?? 'Guest',
      providerId: fbUser.providerData.isNotEmpty
          ? fbUser.providerData[0].providerId
          : 'firebase',
      providerName: fbUser.providerData.isNotEmpty
          ? fbUser.providerData[0].providerId
          : 'firebase',
    );
  }
}
