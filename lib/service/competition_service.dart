import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:tictactoe_game/models/competition.dart';

class CompetitionService {
  final FirebaseFirestore _db;
  final FirebaseFunctions _functions;

  CompetitionService({
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
  }) : _db = firestore ?? FirebaseFirestore.instance,
       _functions =
           functions ?? FirebaseFunctions.instanceFor(region: 'us-central1');

  // Returns a week id like 2025-W42 for the current date/time.
  String getCurrentWeekId([DateTime? forDate]) {
    final now = forDate ?? DateTime.now().toUtc();
    final year = now.year;
    final week = _weekOfYear(now);
    return '$year-W$week';
  }

  int _weekOfYear(DateTime date) {
    final firstDay = DateTime(date.year, 1, 1);
    final diff = date.difference(firstDay).inDays + 1;
    return ((diff - date.weekday + 10) / 7).floor();
  }

  CollectionReference<Map<String, dynamic>> _entriesRef(String weekId) =>
      _db.collection('competitions').doc(weekId).collection('entries');

  // Wait for a signed-in user and refresh their ID token.
  Future<fb.User?> waitForSignIn({
    Duration timeout = const Duration(seconds: 5),
  }) async {
    final auth = fb.FirebaseAuth.instance;
    fb.User? user = auth.currentUser;
    if (user == null) {
      try {
        user = await auth
            .authStateChanges()
            .firstWhere((u) => u != null)
            .timeout(timeout);
      } catch (_) {
        return null;
      }
    }

    try {
      await user!.getIdToken(true);
      try {
        await auth
            .idTokenChanges()
            .firstWhere((u) => u?.uid == user!.uid)
            .timeout(const Duration(seconds: 2));
      } catch (_) {}
    } catch (e) {
      debugPrint('Token refresh failed while waiting for sign-in: $e');
    }

    // Log project and functions region for debugging in dev builds.
    try {
      final proj = Firebase.app().options.projectId;
      debugPrint('waitForSignIn: Firebase projectId=$proj');
      // Also log the default functions region we use
      debugPrint('waitForSignIn: Functions region=us-central1');
    } catch (_) {}

    return user;
  }

  /// User joins a tournament (creates entry if not exists)
  Future<void> joinTournament(String weekId, CompetitionEntry entry) async {
    // Ensure the user is signed in and the ID token is fresh/propagated
    final fb.User? user = await waitForSignIn();
    if (user == null) {
      throw StateError('User not signed in');
    }

    // Recreate Functions client so it uses a fresh ID token.
    final functionsClient = FirebaseFunctions.instanceFor(
      region: 'us-central1',
    );
    final callable = functionsClient.httpsCallable('joinTournament');
    try {
      await callable.call({'weekId': weekId, 'userName': entry.userName});
      debugPrint('joinTournament requested via Cloud Function.');
    } on FirebaseFunctionsException catch (fe) {
      if (fe.code == 'unauthenticated') {
        // Try a single refresh+retry
        try {
          await user.getIdToken(true);
          try {
            await fb.FirebaseAuth.instance
                .idTokenChanges()
                .firstWhere((u) => u?.uid == user.uid)
                .timeout(const Duration(seconds: 2));
          } catch (_) {}
          // Recreate the functions client for the retry as well.
          final retryClient = FirebaseFunctions.instanceFor(
            region: 'us-central1',
          );
          final retryCallable = retryClient.httpsCallable('joinTournament');
          await retryCallable.call({
            'weekId': weekId,
            'userName': entry.userName,
          });
          debugPrint('joinTournament requested after token refresh.');
        } catch (e) {
          debugPrint('joinTournament still unauthenticated after retry: $e');

          // If unauthenticated, do NOT write to Firestore from the client
          // (prevents cheating). Try a token-based REST callable fallback.
          try {
            final idToken = await user.getIdToken(true);
            final projectId = Firebase.app().options.projectId;
            final url = Uri.https(
              'us-central1-$projectId.cloudfunctions.net',
              '/joinTournament',
            );
            final client = HttpClient();
            final req = await client.postUrl(url);
            req.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
            req.headers.set(HttpHeaders.authorizationHeader, 'Bearer $idToken');
            req.add(
              utf8.encode(
                jsonEncode({
                  'data': {'weekId': weekId},
                }),
              ),
            );
            final resp = await req.close();
            final body = await resp.transform(utf8.decoder).join();
            debugPrint(
              'joinTournament REST fallback status=${resp.statusCode} body=$body',
            );
            if (resp.statusCode == 200) {
              // Consider success; return to caller.
              return;
            }
          } catch (restErr) {
            debugPrint('REST fallback failed: $restErr');
          }

          rethrow;
        }
      } else {
        debugPrint('Error joining tournament (callable): ${fe.message}');
        rethrow;
      }
    } catch (e) {
      debugPrint('Error joining tournament (callable): $e');
      rethrow;
    }
  }

  Future<CompetitionEntry?> getUserEntry(String weekId, String userId) async {
    try {
      final snap = await _entriesRef(weekId).doc(userId).get();
      if (!snap.exists) return null;
      return CompetitionEntry.fromSnapshot(snap);
    } catch (e) {
      debugPrint('Error getting user entry: $e');
      return null;
    }
  }

  Stream<List<CompetitionEntry>> topEntriesStream(
    String weekId, {
    int limit = 10,
  }) {
    try {
      return _entriesRef(weekId)
          .orderBy('xp', descending: true)
          .limit(limit)
          .snapshots()
          .map(
            (snap) =>
                snap.docs.map((d) => CompetitionEntry.fromSnapshot(d)).toList(),
          );
    } catch (e) {
      debugPrint('Error in topEntriesStream: $e');
      return Stream.value([]);
    }
  }

  Future<List<CompetitionEntry>> getAllEntries(String weekId) async {
    try {
      final snap = await _entriesRef(
        weekId,
      ).orderBy('xp', descending: true).get();
      return snap.docs.map((d) => CompetitionEntry.fromSnapshot(d)).toList();
    } catch (e) {
      debugPrint('Error fetching all entries: $e');
      return [];
    }
  }

  Future<int> getUserRank(String weekId, String userId) async {
    final entry = await getUserEntry(weekId, userId);
    if (entry == null) return -1;
    try {
      final snap = await _entriesRef(
        weekId,
      ).where('xp', isGreaterThan: entry.xp).get();
      return snap.docs.length + 1;
    } catch (e) {
      debugPrint('Error computing rank: $e');
      return -1;
    }
  }

  /// Adds XP via Cloud Function (no direct Firestore write)
  Future<void> addXp(
    String weekId,
    String userId,
    int xpDelta, {
    String? outcome,
  }) async {
    try {
      final callable = _functions.httpsCallable('updateScore');
      await callable.call({
        'weekId': weekId,
        'userId': userId,
        'xpDelta': xpDelta,
        'outcome': outcome ?? '',
      });
      print('XP update sent via Cloud Function.');
    } catch (e) {
      debugPrint('Error calling updateScore Cloud Function: $e');
      rethrow;
    }
  }

  /// Assign league tiers (gold/silver/bronze) based on XP percentiles
  Future<void> finalizeLeagues(String weekId) async {
    // Finalize leagues server-side via a Cloud Function.
    try {
      final callable = _functions.httpsCallable('finalizeLeagues');
      await callable.call({'weekId': weekId});
      debugPrint('finalizeLeagues requested via Cloud Function.');
    } catch (e) {
      debugPrint('Error calling finalizeLeagues Cloud Function: $e');
      rethrow;
    }
  }

  /// Matchmaking system for tournament games
  Future<Map<String, dynamic>> matchmakeForTournament({
    required String weekId,
    required String userId,
    required String userName,
  }) async {
    // Matchmaking is handled server-side to avoid client-side races and
    // enforce rules.
    try {
      // Log a short idToken fingerprint to help debug authentication issues.
      try {
        final fb.User? u = fb.FirebaseAuth.instance.currentUser;
        if (u != null) {
          final token = (await u.getIdToken(true)) ?? '';
          final short = token.length > 16
              ? '${token.substring(0, 8)}...${token.substring(token.length - 8)}'
              : token;
          debugPrint(
            'matchmakeForTournament: uid=${u.uid} token=$short ts=${DateTime.now().toIso8601String()}',
          );
        } else {
          debugPrint(
            'matchmakeForTournament: no currentUser ts=${DateTime.now().toIso8601String()}',
          );
        }
      } catch (diagErr) {
        debugPrint('matchmakeForTournament: diag failed: $diagErr');
      }

      final callable = _functions.httpsCallable('matchmakeForTournament');
      final result = await callable.call({
        'playerId': userId,
        'tournamentId': weekId,
      });
      final data = result.data as Map<String, dynamic>;
      return Map<String, dynamic>.from(data);
    } catch (e) {
      debugPrint('Error calling matchmakeForTournament Cloud Function: $e');
      rethrow;
    }
  }

  /// (Optional) Sends a WhatsApp notification when weekly results are finalized
  Future<void> sendWeeklyWhatsAppUpdate(String weekId) async {
    try {
      final entries = await getAllEntries(weekId);
      if (entries.isEmpty) return;

      final top3 = entries.take(3).toList();
      final message = StringBuffer()
        ..writeln('TicTacToe Weekly Results ($weekId)')
        ..writeln('')
        ..writeln('1st: ${top3[0].userName} — ${top3[0].xp} XP')
        ..writeln(
          top3.length > 1 ? '2nd: ${top3[1].userName} — ${top3[1].xp} XP' : '',
        )
        ..writeln(
          top3.length > 2 ? '3rd: ${top3[2].userName} — ${top3[2].xp} XP' : '',
        )
        ..writeln('')
        ..writeln('Keep up the good work for next week\'s leaderboard.');

      // NOTE: Replace this with your server or WhatsApp Cloud API call.
      debugPrint('WhatsApp update would be sent:\n$message');
    } catch (e) {
      debugPrint('Error sending WhatsApp update: $e');
    }
  }
}
