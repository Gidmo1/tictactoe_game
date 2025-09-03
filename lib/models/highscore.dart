class Highscore {
  final String id;
  final String userName;
  final int score;

  Highscore({required this.id, required this.userName, required this.score});

  Map<String, dynamic> toJson() {
    return {"userName": userName, "id": id, "score": score};
  }

  static Highscore fromJson(Map<String, dynamic> json) {
    return Highscore(
      userName: json['userName'],
      id: json['id'],
      score: json['score'],
    );
  }
}
