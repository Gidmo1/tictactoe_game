class Lobby {
  final String id;
  final String username;

  Lobby({required this.id, required this.username});

  Map<String, dynamic> toJson() {
    return {"userName": username, "id": id};
  }

  static Lobby fromJson(Map<String, dynamic> json) {
    return Lobby(username: json['userName'], id: json['id']);
  }
}
