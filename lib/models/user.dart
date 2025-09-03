class User {
  final String id;
  final String userName;
  final String email;
  final String providerName;
  final String providerId;

  User({
    required this.id,
    required this.userName,
    required this.email,
    required this.providerId,
    required this.providerName,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userName': userName,
      'email': email,
      'providerId': providerId,
      'providerName': providerName,
    };
  }

  static User fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'],
      userName: json['userName'],
      email: json['email'],
      providerId: json['providerId'],
      providerName: json['providerName'],
    );
  }
}
