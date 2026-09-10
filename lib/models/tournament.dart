/// Tournament type: private user-created or official admin-created
enum TournamentType {
  private,
  official,
}

/// Competition format determines how opponents are selected.
enum TournamentFormat {
  /// Official tournament: match any registered player who is currently queued.
  liveMatchmaking,

  /// Official knockout tournament: play only the bracket-assigned opponent.
  cup,

  /// Private tournament: the host starts a bracket when ready; matches are
  /// played during their round deadline rather than at fixed times.
  flexibleBracket,
}

/// Tournament status
enum TournamentStatus {
  waiting,    // Waiting for players to join
  active,     // In progress
  completed,  // Finished
  cancelled,  // Cancelled
}

/// Bracket type
enum BracketType {
  singleElimination,
  doubleElimination,
  roundRobin,
}

/// Grid size for matches
enum GridSize {
  small,    // 3x3
  medium,   // 4x4
  large,    // 5x5
}

/// Represents a tournament
class Tournament {
  final String id;
  final String name;
  final TournamentType type;
  final TournamentFormat format;
  final TournamentStatus status;
  final String createdBy; // User ID of creator (for private) or 'admin' (for official)
  final DateTime createdAt;
  final DateTime? startTime;
  final DateTime? endTime;
  final String? inviteCode; // For private tournaments
  final int maxParticipants;
  final List<String> participants; // User IDs
  final BracketType bracketType;
  final GridSize gridSize;
  final String description;
  final Map<String, dynamic> bracket; // Bracket structure / match results
  final String? winnerUid; // User ID of tournament winner
  final int roundDeadlineHours;
  final DateTime? participantsLockedAt;
  final DateTime? updatedAt;

  Tournament({
    required this.id,
    required this.name,
    required this.type,
    this.format = TournamentFormat.flexibleBracket,
    required this.status,
    required this.createdBy,
    required this.createdAt,
    this.startTime,
    this.endTime,
    this.inviteCode,
    required this.maxParticipants,
    this.participants = const [],
    required this.bracketType,
    required this.gridSize,
    required this.description,
    this.bracket = const {},
    this.winnerUid,
    this.roundDeadlineHours = 48,
    this.participantsLockedAt,
    this.updatedAt,
  });

  /// Check if tournament is full
  bool get isFull => participants.length >= maxParticipants;

  /// Check if tournament can accept new joiners
  bool get canJoin => status == TournamentStatus.waiting && !isFull;

  bool get isBracketBased =>
      format == TournamentFormat.cup ||
      format == TournamentFormat.flexibleBracket;

  bool get participantsAreLocked => participantsLockedAt != null || status != TournamentStatus.waiting;

  /// Copy with optional overrides
  Tournament copyWith({
    String? id,
    String? name,
    TournamentType? type,
    TournamentFormat? format,
    TournamentStatus? status,
    String? createdBy,
    DateTime? createdAt,
    DateTime? startTime,
    DateTime? endTime,
    String? inviteCode,
    int? maxParticipants,
    List<String>? participants,
    BracketType? bracketType,
    GridSize? gridSize,
    String? description,
    Map<String, dynamic>? bracket,
    String? winnerUid,
    int? roundDeadlineHours,
    DateTime? participantsLockedAt,
    DateTime? updatedAt,
  }) {
    return Tournament(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      format: format ?? this.format,
      status: status ?? this.status,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      inviteCode: inviteCode ?? this.inviteCode,
      maxParticipants: maxParticipants ?? this.maxParticipants,
      participants: participants ?? this.participants,
      bracketType: bracketType ?? this.bracketType,
      gridSize: gridSize ?? this.gridSize,
      description: description ?? this.description,
      bracket: bracket ?? this.bracket,
      winnerUid: winnerUid ?? this.winnerUid,
      roundDeadlineHours: roundDeadlineHours ?? this.roundDeadlineHours,
      participantsLockedAt: participantsLockedAt ?? this.participantsLockedAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() => 'Tournament(id: $id, name: $name, type: $type, status: $status)';
}

/// Tournament match within a bracket
class TournamentMatch {
  final String id;
  final String tournamentId;
  final String? player1Uid;
  final String? player2Uid;
  final String? winnerUid;
  final int round;
  final int position; // Position in round
  final bool isCompleted;
  final DateTime? completedAt;
  final DateTime? deadline;
  final String? boardStateJson; // Store final board if needed

  TournamentMatch({
    required this.id,
    required this.tournamentId,
    this.player1Uid,
    this.player2Uid,
    this.winnerUid,
    required this.round,
    required this.position,
    this.isCompleted = false,
    this.completedAt,
    this.deadline,
    this.boardStateJson,
  });

  bool get isReady => player1Uid != null && player2Uid != null;

  TournamentMatch copyWith({
    String? id,
    String? tournamentId,
    String? player1Uid,
    String? player2Uid,
    String? winnerUid,
    int? round,
    int? position,
    bool? isCompleted,
    DateTime? completedAt,
    DateTime? deadline,
    String? boardStateJson,
  }) {
    return TournamentMatch(
      id: id ?? this.id,
      tournamentId: tournamentId ?? this.tournamentId,
      player1Uid: player1Uid ?? this.player1Uid,
      player2Uid: player2Uid ?? this.player2Uid,
      winnerUid: winnerUid ?? this.winnerUid,
      round: round ?? this.round,
      position: position ?? this.position,
      isCompleted: isCompleted ?? this.isCompleted,
      completedAt: completedAt ?? this.completedAt,
      deadline: deadline ?? this.deadline,
      boardStateJson: boardStateJson ?? this.boardStateJson,
    );
  }

  @override
  String toString() => 'TournamentMatch(id: $id, round: $round, completed: $isCompleted)';
}
