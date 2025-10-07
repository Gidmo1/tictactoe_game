class Score {
  final String playerId;
  final String playerName;
  final int wins;
  final int losses;
  final int draws;
  final int points;

  Score({
    required this.playerId,
    required this.playerName,
    this.wins = 0,
    this.losses = 0,
    this.draws = 0,
    this.points = 0,
  });

  Map<String, dynamic> toJson() {
    return {
      'playerId': playerId,
      'playerName': playerName,
      'wins': wins,
      'losses': losses,
      'draws': draws,
      'points': points,
    };
  }

  static Score fromJson(Map<String, dynamic> json) {
    return Score(
      playerId: json['playerId'],
      playerName: json['playerName'],
      wins: json['wins'] ?? 0,
      losses: json['losses'] ?? 0,
      draws: json['draws'] ?? 0,
      points: json['points'] ?? 0,
    );
  }
}
