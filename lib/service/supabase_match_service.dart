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
    debugPrint('[TOURNAMENT] Using dedicated tournament slot code: $code');

    // Preferred path: the dedicated start_or_join_tournament_match RPC
    // (migration 20240004). When that function or its supporting column has
    // not been deployed yet, we transparently fall back to the legacy
    // create_match/join_match flow so matchmaking keeps working.
    try {
      final result = await client.rpc(
        'start_or_join_tournament_match',
        params: {
          'target_tournament_id': tournamentId,
          'target_tournament_match_id': tournamentMatchId,
          'target_board_size': boardSize,
          'target_win_length': winLength,
          'target_opponent_id': opponentId,
        },
      );

      if (result is Map) {
        final map = Map<String, dynamic>.from(result);
        if (map['id'] != null) {
          return map;
        }
        debugPrint('[TOURNAMENT] RPC returned an unusual shape: $result');
      } else {
        debugPrint('[TOURNAMENT] RPC returned a non-map result: $result');
      }
    } catch (error) {
      debugPrint('[TOURNAMENT] start_or_join_tournament_match failed: $error');
    }

    // If the RPC exists but failed mid-flight, try to recover the online
    // match directly by its deterministic tournament slot code. Wrapped so
    // a missing column cannot mask the original error.
    try {
      final recovered = await getTournamentMatchByCode(code);
      if (recovered != null && recovered['id'] != null) {
        debugPrint('[TOURNAMENT] Recovered existing match: ${recovered['id']}');
        return Map<String, dynamic>.from(recovered);
      }
    } catch (readError) {
      debugPrint('[TOURNAMENT] Could not recover match by tournament code: $readError');
    }

    // Legacy fallback (works against the deployed schema without migration
    // 20240004): join a waiting match, otherwise create it. player_o is
    // pre-filled with the opponent, so both sides converge on the same row.
    final existing = await getMatchByInviteCode(code);
    if (existing != null && existing['id'] != null) {
      final String id = existing['id'].toString();
      final String status = (existing['status'] ?? '').toString();
      final bool isParticipant = userId == existing['player_x']?.toString() ||
          userId == existing['player_o']?.toString();

      if (isParticipant && (status == 'active' || status == 'waiting')) {
        debugPrint('[TOURNAMENT] Joining existing match as participant: $id');
        return Map<String, dynamic>.from(existing);
      }

      if (status == 'waiting' && !isParticipant) {
        try {
          debugPrint('[TOURNAMENT] Joining existing waiting match: $id');
          return await joinMatch(matchId: code);
        } catch (joinError) {
          debugPrint('[TOURNAMENT] Legacy join failed: $joinError');
        }
      }
    }

    try {
      final created = await createMatch(
        boardSize: boardSize,
        winLength: winLength,
        opponentId: opponentId,
        inviteCode: code,
      );
      if (created['id'] != null) {
        // The create_match RPC silently regenerates the invite code whenever
        // it is already taken. That means the other player won the race and
        // already holds the slot match — converge on their row so both sides
        // land in the same online match.
        final createdCode =
            (created['invite_code'] ?? '').toString().toUpperCase();
        if (createdCode.isNotEmpty && createdCode != code) {
          debugPrint('[TOURNAMENT] Slot code was taken; joining winner');
          final raced = await getMatchByInviteCode(code);
          if (raced != null && raced['id'] != null) {
            debugPrint('[TOURNAMENT] Joined winner match: ${raced['id']}');
            return Map<String, dynamic>.from(raced);
          }
          debugPrint('[TOURNAMENT] Winner match not found; using own row');
        } else {
          debugPrint('[TOURNAMENT] Created fallback match: ${created['id']}');
        }
        return created;
      }
      throw StateError('Online match was not created');
    } catch (createError) {
      // Two players attempting to create at the same time: the loser may hit
      // a unique invite_code violation and recovers the winner's row below.
      debugPrint('[TOURNAMENT] Legacy create failed: $createError; checking for race');
      final raced = await getMatchByInviteCode(code);
      if (raced != null && raced['id'] != null) {
        debugPrint('[TOURNAMENT] Found race-created match: ${raced['id']}');
        return Map<String, dynamic>.from(raced);
      }
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

  Future<Map<String, dynamic>?> getTournamentMatchByCode(String inviteCode) async {
    final code = inviteCode.trim().toUpperCase();
    if (code.isEmpty) return null;

    return await client
        .from('matches')
        .select()
        .eq('tournament_match_code', code)
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