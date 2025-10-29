import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:app_links/app_links.dart';

class InviteService {
  static final InviteService _instance = InviteService._internal();
  factory InviteService() => _instance;
  InviteService._internal();

  static const String _scheme = 'tictactoe';
  static const String _host = 'join';
  static StreamSubscription<Uri>? _sub;

  /// Generates a random match ID
  String generateMatchId() {
    final rand = Random();
    return 'match_${DateTime.now().millisecondsSinceEpoch}_${rand.nextInt(9999)}';
  }

  /// Creates a deep link for your app
  String createInviteLink(String matchId) {
    return '$_scheme://$_host?matchId=$matchId';
  }

  /// Fallback web link (used for WhatsApp or if app isn't installed)
  String createWebFallbackLink(String matchId) {
    return 'https://mytictactoe.example.app/join?matchId=$matchId';
  }

  // Share link via WhatsApp (or copy to clipboard if not available)
  Future<void> shareViaWhatsApp(BuildContext context, String matchId) async {
    // deepLink intentionally not used for WhatsApp sharing; web fallback used
    final webFallback = createWebFallbackLink(matchId);

    // WhatsApp only highlights clickable HTTP/HTTPS URLs, not custom schemes
    final encodedMessage = Uri.encodeComponent(
      '🎮 Join my TicTacToe game and let\'s play! Who do you think will win? \nTap below to join:\n👉 $webFallback',
    );

    final whatsappUrl = Uri.parse('https://wa.me/?text=$encodedMessage');

    try {
      final launched = await launchUrl(
        whatsappUrl,
        mode: LaunchMode.externalApplication,
      );

      if (!launched) throw Exception('WhatsApp not available');
    } catch (e) {
      // Fallback: copy link to clipboard
      await Clipboard.setData(ClipboardData(text: webFallback));

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'WhatsApp not installed — invite link copied!',
              style: TextStyle(color: Colors.white),
            ),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
      debugPrint(' WhatsApp share failed: $e');
    }
  }

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
