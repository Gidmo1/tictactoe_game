import 'dart:math';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:tictactoe_game/models/tournament.dart';
import 'package:tictactoe_game/service/bracket_service.dart';
import 'package:flutter/foundation.dart';

/// Service for tournament CRUD operations
class TournamentService {
  final SupabaseClient _supabase = Supabase.instance.client;
  String? lastJoinError;

  /// Create a new private tournament
  Future<Tournament> createPrivateTournament({
    required String name,
    required String description,
    required String createdBy,
    required int maxParticipants,
    required BracketType bracketType,
    required GridSize gridSize,
  }) async {
    try {
      final id = const Uuid().v4();
      final inviteCode = await _generateUniqueInviteCode();
      final now = DateTime.now();

      final tournament = Tournament(
        id: id,
        name: name,
        type: TournamentType.private,
        status: TournamentStatus.waiting,
        createdBy: createdBy,
        createdAt: now,
        inviteCode: inviteCode,
        maxParticipants: maxParticipants,
        participants: [createdBy],
        bracketType: bracketType,
        gridSize: gridSize,
        description: description,
      );

      // Save to Supabase
      await _supabase.from('tournaments').insert({
        'id': tournament.id,
        'name': tournament.name,
        'type': tournament.type.name,
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
      final response = await _supabase
          .from('tournaments')
          .select()
          .eq('invite_code', inviteCode)
          .eq('type', 'private')
          .eq('status', 'waiting')
          .maybeSingle();

      if (response == null) {
        lastJoinError = 'Tournament not found or already started';
        debugPrint('Tournament not found with invite code: $inviteCode');
        return false;
      }

      final tournament = _rowToTournament(response);

      // Check if already joined
      if (tournament.participants.contains(userUid)) {
        debugPrint('User already in tournament; treating join as successful');
        return true;
      }

      // Check if tournament is full
      if (tournament.isFull) {
        lastJoinError = 'Tournament is full';
        debugPrint('Tournament is full');
        return false;
      }

      // Add participant
      final updatedParticipants = [...tournament.participants, userUid];
      debugPrint('[JOIN] Before update: participants = ${tournament.participants}, trying to add $userUid');
      await _supabase.from('tournaments').update({
        'participants': updatedParticipants,
      }).eq('id', tournament.id);
      debugPrint('[JOIN] After update: sent participants = $updatedParticipants');

      // Verify update by re-fetching immediately
      final verifyResponse = await _supabase
          .from('tournaments')
          .select()
          .eq('id', tournament.id)
          .maybeSingle();
      final verifyTournament = verifyResponse != null ? _rowToTournament(verifyResponse) : null;
      debugPrint('[JOIN] Verification: actual participants in DB = ${verifyTournament?.participants}');
      
      debugPrint('User $userUid joined tournament ${tournament.id}');
      return true;
    } catch (e) {
      lastJoinError = 'Could not update tournament membership';
      debugPrint('Error joining tournament: $e');
      return false;
    }
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
      if (tournament.status != TournamentStatus.waiting ||
          tournament.participants.length < 2) {
        debugPrint('Tournament cannot start in its current state');
        return false;
      }

      // Generate bracket
      final bracket = BracketService.generateSingleElimination(
        tournament.participants,
      );

      // Update tournament
      await _supabase.from('tournaments').update({
        'status': 'active',
        'start_time': DateTime.now().toIso8601String(),
        'bracket': bracket,
      }).eq('id', tournamentId);

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

      await _supabase
          .from('tournaments')
          .update({'status': TournamentStatus.cancelled.name})
          .eq('id', tournamentId);
      return true;
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

      final bracket = tournament.bracket;
      BracketService.completeMatch(bracket, matchId, winnerUid);

      // Check if tournament is over
      String? tournamentWinner;
      String status = 'active';
      if (BracketService.isTournamentOver(bracket)) {
        status = 'completed';
        tournamentWinner = BracketService.getTournamentWinner(bracket);
      }

      await _supabase.from('tournaments').update({
        'bracket': bracket,
        'status': status,
        'winner_uid': tournamentWinner,
        'end_time': status == 'completed' ? DateTime.now().toIso8601String() : null,
      }).eq('id', tournamentId);

      debugPrint('Completed match $matchId in tournament $tournamentId');
      return true;
    } catch (e) {
      debugPrint('Error completing match: $e');
      return false;
    }
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
      bracketType: BracketType.values.byName(row['bracket_type'] as String),
      gridSize: GridSize.values.byName(row['grid_size'] as String),
      description: row['description'] as String,
      bracket: (row['bracket'] as Map<String, dynamic>?) ?? {},
      winnerUid: row['winner_uid'] as String?,
    );
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
