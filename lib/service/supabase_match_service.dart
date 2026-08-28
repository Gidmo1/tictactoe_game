import 'dart:async';

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

  Future<void> cancelSubscription(StreamSubscription<dynamic>? subscription) {
    return subscription?.cancel() ?? Future<void>.value();
  }
}
