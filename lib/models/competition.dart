import 'package:cloud_firestore/cloud_firestore.dart';

class CompetitionEntry {
  final String userId;
  final String userName;
  final int xp;
  final int wins;
  final int draws;
  final int losses;
  final DateTime joinedAt;
  final String league;

  CompetitionEntry({
    required this.userId,
    required this.userName,
    required this.xp,
    required this.wins,
    required this.draws,
    required this.losses,
    required this.joinedAt,
    required this.league,
  });

  Map<String, dynamic> toMap() => {
    'userId': userId,
    'userName': userName,
    'xp': xp,
    'wins': wins,
    'draws': draws,
    'losses': losses,
    'joinedAt': Timestamp.fromDate(joinedAt),
    'league': league,
  };

  factory CompetitionEntry.fromMap(Map<String, dynamic> map) {
    return CompetitionEntry(
      userId: map['userId'] as String? ?? '',
      userName: map['userName'] as String? ?? '',
      xp: (map['xp'] as num?)?.toInt() ?? 0,
      wins: (map['wins'] as num?)?.toInt() ?? 0,
      draws: (map['draws'] as num?)?.toInt() ?? 0,
      losses: (map['losses'] as num?)?.toInt() ?? 0,
      joinedAt: (map['joinedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      league: map['league'] as String? ?? '',
    );
  }

  factory CompetitionEntry.fromSnapshot(DocumentSnapshot snap) {
    final map = snap.data() as Map<String, dynamic>? ?? {};
    return CompetitionEntry.fromMap(map);
  }
}
