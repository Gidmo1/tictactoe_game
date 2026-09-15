import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseMatchService {
  final SupabaseClient client;

  SupabaseMatchService({SupabaseClient? client})
    : client = client ?? Supabase.instance.client;

  String? get userId => client.auth.currentUser?.id;

  void _requireSignedIn() {
    if (userId == null) {
      throw StateError('Sign in required for online matches.');
    }
  }

  /// Deterministic invite code for a tournament bracket slot so both players
  /// can safely start-or-join the same online match without a race.
  static String tournamentMatchInviteCode({
    required String tournamentId,
    required String tournamentMatchId,
  }) {
    final raw = 'T${tournamentId.replaceAll('-', '')}'
        '${tournamentMatchId.replaceAll('-', '')}';
    return raw.substring(0, raw.length.clamp(0, 12)).toUpperCase();
  }

  Future<Map<String, dynamic>> createMatch({
    required int boardSize,
    required int winLength,
    String? opponentId,
    String? inviteCode,
  }) async {
    _requireSignedIn();

    final result = await client.rpc(
      'create_match',
      params: {
        'match_board_size': boardSize,
        'match_win_length': winLength,
        'match_opponent_id': opponentId,
        'match_invite_code': inviteCode,
      },
    );

    return Map<String, dynamic>.from(result as Map);
  }

  /// Start or join the online match for a tournament bracket slot.
  /// Either player can call this; the second caller joins the existing row.
  Future<Map<String, dynamic>> startOrJoinTournamentMatch({
    required String tournamentId,
    required String tournamentMatchId,
    required int boardSize,
    required int winLength,
    required String opponentId,
  }) async {
    _requireSignedIn();

    final code = tournamentMatchInviteCode(
      tournamentId: tournamentId,
      tournamentMatchId: tournamentMatchId,
    );
    debugPrint('[TOURNAMENT] Generated invite code: $code');

    final existing = await getMatchByInviteCode(code);
    if (existing != null) {
      final id = existing['id']?.toString();
      final status = (existing['status'] ?? '').toString();
      final isParticipant = userId == existing['player_x'] ||
          userId == existing['player_o'];

      debugPrint('[TOURNAMENT] Found existing match: id=$id, status=$status, isParticipant=$isParticipant');

      if (id != null && isParticipant) {
        debugPrint('[TOURNAMENT] Returning existing match (already participant)');
        return Map<String, dynamic>.from(existing);
      }

      if (id != null && status == 'waiting') {
        try {
          debugPrint('[TOURNAMENT] Joining existing waiting match...');
          return await joinMatch(matchId: code);
        } catch (e) {
          debugPrint('[TOURNAMENT] Join failed: $e');
        }
      }

      if (id != null && isParticipant) {
        debugPrint('[TOURNAMENT] Returning existing match (participant check 2)');
        return Map<String, dynamic>.from(existing);
      }
    }

    debugPrint('[TOURNAMENT] Creating new match with code: $code');
    try {
      final created = await createMatch(
        boardSize: boardSize,
        winLength: winLength,
        opponentId: opponentId,
        inviteCode: code,
      );
      debugPrint('[TOURNAMENT] Match created successfully: ${created['id']}');
      return created;
    } catch (e) {
      debugPrint('[TOURNAMENT] Create failed: $e, checking for race condition...');
      final raced = await getMatchByInviteCode(code);
      if (raced != null) {
        debugPrint('[TOURNAMENT] Found race-created match: ${raced['id']}');
        return Map<String, dynamic>.from(raced);
      }
      debugPrint('[TOURNAMENT] No race match found, rethrowing: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> joinMatch({required String matchId}) async {
    _requireSignedIn();

    final result = await client.rpc(
      'join_match',
      params: {
        'target_match_code': matchId,
      },
    );

    return Map<String, dynamic>.from(result as Map);
  }

  Future<Map<String, dynamic>> cancelMatch({required String matchId}) async {
    _requireSignedIn();

    final result = await client.rpc(
      'cancel_match',
      params: {
        'target_match_code': matchId,
      },
    );

    return Map<String, dynamic>.from(result as Map);
  }

  Future<Map<String, dynamic>?> getMatch(String matchId) async {
    return await client
        .from('matches')
        .select()
        .eq('id', matchId)
        .maybeSingle();
  }

  Future<Map<String, dynamic>?> getMatchByInviteCode(String inviteCode) async {
    final code = inviteCode.trim().toUpperCase();
    if (code.isEmpty) return null;

    return await client
        .from('matches')
        .select()
        .eq('invite_code', code)
        .maybeSingle();
  }

  Stream<Map<String, dynamic>> watchMatch(String matchId) {
    return client
        .from('matches')
        .stream(primaryKey: ['id'])
        .eq('id', matchId)
        .map((rows) => rows.isEmpty ? <String, dynamic>{} : rows.first);
  }

  Future<Map<String, dynamic>> submitMove({
    required String matchId,
    required int row,
    required int col,
  }) async {
    _requireSignedIn();

    final result = await client.rpc(
      'submit_move',
      params: {
        'target_match_id': matchId,
        'move_row': row,
        'move_col': col,
      },
    );

    return Map<String, dynamic>.from(result as Map);
  }

  Future<void> reconnect(String matchId) async {
    final match = await getMatch(matchId);
    if (match == null) throw StateError('Match no longer exists');

    final currentUserId = userId;
    if (currentUserId == null ||
        (match['player_x'] != currentUserId &&
            match['player_o'] != currentUserId)) {
      throw StateError('You are not a participant in this match');
    }
  }

  Future<void> recordOpponentDisconnect({
    required String matchId,
    required String opponentId,
  }) async {
    _requireSignedIn();
    await client.rpc(
      'record_match_disconnect',
      params: {
        'target_match_id': matchId,
        'target_disconnected_player_id': opponentId,
      },
    );
  }

  Future<void> clearDisconnect({required String matchId}) async {
    _requireSignedIn();
    await client.rpc(
      'clear_match_disconnect',
      params: {'target_match_id': matchId},
    );
  }

  Future<Map<String, dynamic>> claimDisconnect({
    required String matchId,
  }) async {
    _requireSignedIn();
    final result = await client.rpc(
      'claim_match_disconnect',
      params: {'target_match_id': matchId},
    );
    return Map<String, dynamic>.from(result as Map);
  }

  Future<void> cancelSubscription(StreamSubscription<dynamic>? subscription) {
    return subscription?.cancel() ?? Future<void>.value();
  }
}