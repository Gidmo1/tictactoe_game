import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:app_links/app_links.dart';

class InviteService {
  static final InviteService _instance = InviteService._internal();
  factory InviteService() => _instance;
  InviteService._internal();

  static const String _scheme = 'tictactoe';
  static const String _host = 'join';
  static StreamSubscription<Uri>? _sub;

  // Generates a random match ID
  String generateMatchId() {
    final rand = Random();
    return 'match_${DateTime.now().millisecondsSinceEpoch}_${rand.nextInt(9999)}';
  }

  // Creates a deep link for my game
  String createInviteLink(String matchId) {
    return '$_scheme://$_host?matchId=$matchId';
  }

  // Note: WhatsApp-specific sharing was removed. Invites are created and
  // consumed in-app using the Friend Invite screen or deep links.

  // Listen for incoming deep links while app is open
  static void listenForInvites(void Function(String matchId) onInviteReceived) {
    final appLinks = AppLinks();
    _sub?.cancel();
    _sub = appLinks.uriLinkStream.listen((uri) {
      if (uri.scheme == _scheme && uri.host == _host) {
        final matchId = uri.queryParameters['matchId'];
        if (matchId != null) onInviteReceived(matchId);
      }
    }, onError: (err) => debugPrint('InviteService stream error: $err'));
  }

  // Handle cold start (when app is opened via invite link)
  static Future<String?> getInitialInvite() async {
    try {
      final appLinks = AppLinks();
      final initialUri = await appLinks.getInitialLink();
      if (initialUri != null &&
          initialUri.scheme == _scheme &&
          initialUri.host == _host) {
        return initialUri.queryParameters['matchId'];
      }
    } catch (e) {
      debugPrint('Error getting initial invite: $e');
    }
    return null;
  }

  // Stop listening (avoid memory leaks)
  static void dispose() {
    _sub?.cancel();
    _sub = null;
  }
}
