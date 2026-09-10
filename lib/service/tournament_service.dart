import 'dart:convert';
import 'dart:math';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:tictactoe_game/models/tournament.dart';
import 'package:tictactoe_game/service/bracket_service.dart';
import 'package:flutter/foundation.dart';

/// Service for tournament CRUD operations
class TournamentService {
  final SupabaseClient _supabase;
  String? lastJoinError;

  TournamentService({SupabaseClient? supabase})
      : _supabase = supabase ?? Supabase.instance.client;

  /// Create a new private tournament
  Future<Tournament> createPrivateTournament({
    required String name,
    required String description,
    required String createdBy,
    required int maxParticipants,
    required BracketType bracketType,
    required GridSize gridSize,
    int roundDeadlineHours = 48,
  }) async {
    try {
      if (maxParticipants < 2 || maxParticipants > 16) {
        throw ArgumentError.value(
          maxParticipants,
          'maxParticipants',
          'must be between 2 and 16',
        );
      }
      if (roundDeadlineHours < 1 || roundDeadlineHours > 168) {
        throw ArgumentError.value(
          roundDeadlineHours,
          'roundDeadlineHours',
          'must be between 1 and 168',
        );
      }
      final id = const Uuid().v4();
      final inviteCode = await _generateUniqueInviteCode();
      final now = DateTime.now();

      final tournament = Tournament(
        id: id,
        name: name,
        type: TournamentType.private,
        format: TournamentFormat.flexibleBracket,
        status: TournamentStatus.waiting,
        createdBy: createdBy,
        createdAt: now,
        inviteCode: inviteCode,
        maxParticipants: maxParticipants,
        participants: [createdBy],
        bracketType: bracketType,
        gridSize: gridSize,
        description: description,
        roundDeadlineHours: roundDeadlineHours,
      );

      // Save to Supabase
      await _supabase.from('tournaments').insert({
        'id': tournament.id,
        'name': tournament.name,
        'type': tournament.type.name,
        'format': tournament.format.name,
        'status': tournament.status.name,
        'created_by': tournament.createdBy,
        'created_at': tournament.createdAt.toIso8601String(),
        'invite_code': tournament.inviteCode,
        'max_participants': tournament.maxParticipants,
        'participants': tournament.participants,
        'bracket_type': tournament.bracketType.name,
        'grid_size': tournament.gridSize.name,
        'description': tournament.description,
        'bracket': tournament.bracket,
        'round_deadline_hours': tournament.roundDeadlineHours,
      });

      debugPrint('Created private tournament: $id');
      return tournament;
    } catch (e) {
      debugPrint('Error creating private tournament: $e');
      rethrow;
    }
  }

  /// Join a private tournament by invite code
  Future<bool> joinTournament({
    required String inviteCode,
    required String userUid,
  }) async {
    lastJoinError = null;
    try {
      final result = await _supabase.rpc(
        'join_tournament',
        params: {'target_invite_code': inviteCode.trim().toUpperCase()},
      );
      final joined = Map<String, dynamic>.from(result as Map);
      debugPrint(
        'User $userUid joined tournament ${joined['id'] ?? inviteCode}',
      );
      return true;
    } catch (e) {
      lastJoinError = _friendlyTournamentError(e, fallback: 'Could not join tournament');
      debugPrint('Error joining tournament: $e');
      return false;
    }
  }

  /// Register the signed-in user for an official tournament.
  Future<bool> registerForOfficialTournament({
    required String tournamentId,
  }) async {
    try {
      await _supabase.rpc(
        'register_tournament_participant',
        params: {'target_tournament_id': tournamentId},
      );
      return true;
    } catch (e) {
      lastJoinError = _friendlyTournamentError(
        e,
        fallback: 'Could not register for tournament',
      );
      debugPrint('Error registering for official tournament: $e');
      return false;
    }
  }

  /// Enter an official live-matchmaking queue.
  ///
  /// The server returns `queued` until another registered participant is
  /// waiting, then returns `matched` with the online match payload.
  Future<Map<String, dynamic>> enterOfficialMatchmaking({
    required String tournamentId,
    required int boardSize,
    required int winLength,
  }) async {
    final result = await _supabase.rpc(
      'join_official_matchmaking',
      params: {
        'target_tournament_id': tournamentId,
        'match_board_size': boardSize,
        'match_win_length': winLength,
      },
    );
    return Map<String, dynamic>.from(result as Map);
  }

  /// Get tournament by ID
  Future<Tournament?> getTournament(String tournamentId) async {
    try {
      final response = await _supabase
          .from('tournaments')
          .select()
          .eq('id', tournamentId)
          .maybeSingle();

      if (response == null) {
        debugPrint('[GET] Tournament $tournamentId not found!');
        return null;
      }
      final result = _rowToTournament(response);
      debugPrint('[GET] Tournament $tournamentId: participants = ${result.participants}');
      return result;
    } catch (e) {
      debugPrint('Error getting tournament: $e');
      return null;
    }
  }

  /// Get tournament by invite code
  Future<Tournament?> getTournamentByInviteCode(String inviteCode) async {
    try {
      final response = await _supabase
          .from('tournaments')
          .select()
          .eq('invite_code', inviteCode)
          .maybeSingle();

      if (response == null) return null;
      return _rowToTournament(response);
    } catch (e) {
      debugPrint('Error getting tournament by invite code: $e');
      return null;
    }
  }

  /// Get all active private tournaments (waiting to start)
  Future<List<Tournament>> getActivePrivateTournaments() async {
    try {
      final response = await _supabase
          .from('tournaments')
          .select()
          .eq('type', 'private')
          .inFilter('status', ['waiting', 'active'])
          .order('created_at', ascending: false);

      return (response as List).map((row) => _rowToTournament(row)).toList();
    } catch (e) {
      debugPrint('Error fetching active private tournaments: $e');
      return [];
    }
  }

  /// Get all official tournaments
  Future<List<Tournament>> getOfficialTournaments() async {
    try {
      final response = await _supabase
          .from('tournaments')
          .select()
          .eq('type', 'official')
          .order('start_time', ascending: false);

      return (response as List).map((row) => _rowToTournament(row)).toList();
    } catch (e) {
      debugPrint('Error fetching official tournaments: $e');
      return [];
    }
  }

  /// Get user's active tournament participation
  Future<Tournament?> getUserActiveTournament(String userUid) async {
    try {
      final response = await _supabase
          .from('tournaments')
          .select()
          .filter('participants', 'cs', '{$userUid}')
          .inFilter('status', ['waiting', 'active'])
          .maybeSingle();

      if (response == null) return null;
      return _rowToTournament(response);
    } catch (e) {
      debugPrint('Error getting user active tournament: $e');
      return null;
    }
  }

  /// Start a tournament (generate bracket and begin matches)
  Future<bool> startTournament(String tournamentId) async {
    try {
      final tournament = await getTournament(tournamentId);
      if (tournament == null) return false;

      final currentUserId = _supabase.auth.currentUser?.id;
      if (currentUserId == null || currentUserId != tournament.createdBy) {
        debugPrint('Only the tournament creator can start this tournament');
        return false;
      }
      final canStartBracket = (tournament.type == TournamentType.private &&
              tournament.format == TournamentFormat.flexibleBracket) ||
          (tournament.type == TournamentType.official &&
              tournament.format == TournamentFormat.cup);
      if (tournament.status != TournamentStatus.waiting ||
          !canStartBracket ||
          tournament.participants.length < 2 ||
          tournament.participants.length > tournament.maxParticipants) {
        debugPrint('Tournament cannot start in its current state');
        return false;
      }

      // Generate bracket
      final startedAt = DateTime.now();
      final bracket = BracketService.generateSingleElimination(
        tournament.participants,
        startedAt: startedAt,
        roundDeadlineHours: tournament.roundDeadlineHours,
        format: tournament.format,
      );
      if (bracket.isEmpty) return false;

      // The RPC locks the row and re-checks the host, status, and participant
      // list. A direct update here would reintroduce the join/start race.
      await _supabase.rpc(
        'start_tournament',
        params: {
          'target_tournament_id': tournamentId,
          'target_bracket': bracket,
          'target_round_deadline_hours': tournament.roundDeadlineHours,
          'expected_updated_at': tournament.updatedAt?.toIso8601String(),
        },
      );

      debugPrint('Started tournament: $tournamentId');
      return true;
    } catch (e) {
      debugPrint('Error starting tournament: $e');
      return false;
    }
  }

  /// Cancel a waiting tournament without deleting its history.
  Future<bool> cancelTournament(String tournamentId) async {
    try {
      final tournament = await getTournament(tournamentId);
      final currentUserId = _supabase.auth.currentUser?.id;
      if (tournament == null ||
          currentUserId == null ||
          currentUserId != tournament.createdBy ||
          tournament.status != TournamentStatus.waiting) {
        return false;
      }

      final cancelled = await _supabase
          .from('tournaments')
          .update({'status': TournamentStatus.cancelled.name})
          .eq('id', tournamentId)
          .eq('status', TournamentStatus.waiting.name)
          .select('id')
          .maybeSingle();
      return cancelled != null;
    } catch (e) {
      debugPrint('Error cancelling tournament: $e');
      return false;
    }
  }

  /// Complete a match and advance winner
  Future<bool> completeMatch({
    required String tournamentId,
    required String matchId,
    required String winnerUid,
  }) async {
    try {
      final tournament = await getTournament(tournamentId);
      if (tournament == null) return false;
      if (tournament.status != TournamentStatus.active ||
          !tournament.isBracketBased) {
        return false;
      }

      final currentUserId = _supabase.auth.currentUser?.id;
      if (currentUserId == null) return false;

      final pendingMatch = _pendingMatch(tournament.bracket, matchId);
      if (pendingMatch == null ||
          (pendingMatch['player1'] != currentUserId &&
              pendingMatch['player2'] != currentUserId) ||
          (pendingMatch['player1'] != winnerUid &&
              pendingMatch['player2'] != winnerUid)) {
        return false;
      }

      final bracket = _deepCopyBracket(tournament.bracket);
      final completed = BracketService.completeMatchAt(
        bracket,
        matchId,
        winnerUid,
        now: DateTime.now(),
        roundDeadlineHours: tournament.roundDeadlineHours,
      );
      if (!completed) return false;

      await _supabase.rpc(
        'complete_tournament_match',
        params: {
          'target_tournament_id': tournamentId,
          'target_match_id': matchId,
          'target_winner_uid': winnerUid,
          'target_bracket': bracket,
          'expected_updated_at': tournament.updatedAt?.toIso8601String(),
        },
      );

      debugPrint('Completed match $matchId in tournament $tournamentId');
      return true;
    } catch (e) {
      debugPrint('Error completing match: $e');
      return false;
    }
  }

  /// Claim a forfeit after the server-side round deadline has passed.
  Future<bool> forfeitMatch({
    required String tournamentId,
    required String matchId,
  }) async {
    final tournament = await getTournament(tournamentId);
    final currentUserId = _supabase.auth.currentUser?.id;
    if (tournament == null || currentUserId == null) return false;

    final pendingMatch = _pendingMatch(tournament.bracket, matchId);
    if (pendingMatch == null ||
        (pendingMatch['player1'] != currentUserId &&
            pendingMatch['player2'] != currentUserId) ||
        !BracketService.isPastDeadline(pendingMatch)) {
      return false;
    }

    final opponent = pendingMatch['player1'] == currentUserId
        ? pendingMatch['player2']
        : pendingMatch['player1'];
    if (opponent is! String || opponent.isEmpty) return false;

    final bracket = _deepCopyBracket(tournament.bracket);
    if (!BracketService.completeMatchAt(
      bracket,
      matchId,
      currentUserId,
      now: DateTime.now(),
      roundDeadlineHours: tournament.roundDeadlineHours,
    )) {
      return false;
    }

    try {
      await _supabase.rpc(
        'complete_tournament_match',
        params: {
          'target_tournament_id': tournamentId,
          'target_match_id': matchId,
          'target_winner_uid': currentUserId,
          'target_bracket': bracket,
          'is_forfeit': true,
          'expected_updated_at': tournament.updatedAt?.toIso8601String(),
        },
      );
      return true;
    } catch (e) {
      debugPrint('Error claiming tournament forfeit: $e');
      return false;
    }
  }

  Map<String, dynamic> _deepCopyBracket(Map<String, dynamic> bracket) {
    return Map<String, dynamic>.from(
      (jsonDecode(jsonEncode(bracket)) as Map).cast<String, dynamic>(),
    );
  }

  Map<String, dynamic>? _pendingMatch(
    Map<String, dynamic> bracket,
    String matchId,
  ) {
    for (final match in BracketService.getPendingMatches(bracket)) {
      if (match['id'] == matchId) return match;
    }
    return null;
  }

  /// Helper: Convert DB row to Tournament object
  Tournament _rowToTournament(Map<String, dynamic> row) {
    return Tournament(
      id: row['id'] as String,
      name: row['name'] as String,
      type: TournamentType.values.byName(row['type'] as String),
      status: TournamentStatus.values.byName(row['status'] as String),
      createdBy: row['created_by'] as String,
      createdAt: DateTime.parse(row['created_at'] as String),
      startTime: row['start_time'] != null ? DateTime.parse(row['start_time'] as String) : null,
      endTime: row['end_time'] != null ? DateTime.parse(row['end_time'] as String) : null,
      inviteCode: row['invite_code'] as String?,
      maxParticipants: row['max_participants'] as int,
      participants: List<String>.from(row['participants'] as List? ?? []),
      bracketType: BracketType.values.byName(
        (row['bracket_type'] as String?) ?? BracketType.singleElimination.name,
      ),
      gridSize: GridSize.values.byName(row['grid_size'] as String),
      description: row['description'] as String? ?? '',
      bracket: (row['bracket'] as Map<String, dynamic>?) ?? {},
      winnerUid: row['winner_uid'] as String?,
      format: _formatFromRow(row),
      roundDeadlineHours:
          (row['round_deadline_hours'] as num?)?.toInt() ?? 48,
      participantsLockedAt: row['participants_locked_at'] == null
          ? null
          : DateTime.tryParse(row['participants_locked_at'].toString()),
      updatedAt: row['updated_at'] == null
          ? null
          : DateTime.tryParse(row['updated_at'].toString()),
    );
  }

  TournamentFormat _formatFromRow(Map<String, dynamic> row) {
    final raw = row['format'] as String?;
    if (raw != null) {
      return TournamentFormat.values.firstWhere(
        (value) => value.name == raw,
        orElse: () => row['type'] == TournamentType.official.name
            ? TournamentFormat.liveMatchmaking
            : TournamentFormat.flexibleBracket,
      );
    }
    return row['type'] == TournamentType.official.name
        ? TournamentFormat.liveMatchmaking
        : TournamentFormat.flexibleBracket;
  }

  String _friendlyTournamentError(
    Object error, {
    required String fallback,
  }) {
    final message = error.toString().toLowerCase();
    if (message.contains('full')) return 'Tournament is full';
    if (message.contains('not found') || message.contains('unavailable')) {
      return 'Tournament not found or no longer available';
    }
    if (message.contains('started') || message.contains('locked')) {
      return 'Tournament registration is closed';
    }
    return fallback;
  }

  Future<String> _generateUniqueInviteCode() async {
    for (var attempt = 0; attempt < 8; attempt++) {
      final candidate = _generateInviteCode();
      final existing = await _supabase
          .from('tournaments')
          .select('id')
          .eq('invite_code', candidate)
          .maybeSingle();
      if (existing == null) return candidate;
    }
    throw StateError('Could not generate a unique tournament invite code');
  }

  /// Generate a random invite code (6 chars)
  String _generateInviteCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random.secure();
    return List.generate(6, (index) => chars[random.nextInt(chars.length)]).join();
  }
}
