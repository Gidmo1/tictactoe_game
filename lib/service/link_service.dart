import 'dart:async';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:app_links/app_links.dart';

class LinkService {
  static const String appScheme = 'tictactoe';
  static const String host = 'join'; // used for deep link detection
  static const String webDomain = 'https://tictactoeapp.com'; // fallback site

  /// Generate a custom invite link for your game
  static String createInviteLink(String matchId) {
    // Example: tictactoe://join?matchId=abc123
    return '$appScheme://$host?matchId=$matchId';
  }

  /// Generate a fallback web link (optional)
  static String createWebFallbackLink(String matchId) {
    // Example: https://tictactoeapp.com/join?matchId=abc123
    return '$webDomain/join?matchId=$matchId';
  }

  /// Send the invite link through WhatsApp or fallback to browser
  static Future<void> sendInviteViaWhatsApp(String matchId) async {
    final link = createInviteLink(matchId);
    final text = Uri.encodeComponent('Hey! Join my TicTacToe game: $link');
    final whatsappUrl = Uri.parse('https://wa.me/?text=$text');
    final fallback = Uri.parse(createWebFallbackLink(matchId));

    try {
      if (await canLaunchUrl(whatsappUrl)) {
        await launchUrl(whatsappUrl, mode: LaunchMode.externalApplication);
      } else {
        await launchUrl(fallback, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint(' Could not send WhatsApp invite: $e');
    }
  }

  /// Open a link directly (e.g. tictactoe://join?matchId=xyz)
  static Future<void> openLink(String link) async {
    final uri = Uri.parse(link);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        debugPrint(' Could not open $link');
      }
    } catch (e) {
      debugPrint(' Failed to open link: $e');
    }
  }

  /// Stream subscription for deep links
  static StreamSubscription<Uri>? _sub;

  /// Start listening for deep links (when the app is already open)
  static void startListening(
    BuildContext context,
    Function(String matchId) onMatchJoin,
  ) {
    final appLinks = AppLinks();

    _sub?.cancel(); // avoid duplicate listeners
    _sub = appLinks.uriLinkStream.listen(
      (Uri uri) {
        try {
          if (uri.scheme == appScheme && uri.host == host) {
            final matchId = uri.queryParameters['matchId'];
            if (matchId != null && matchId.isNotEmpty) {
              debugPrint(' Incoming invite detected: matchId=$matchId');
              onMatchJoin(matchId);
            }
          }
        } catch (e) {
          debugPrint(' LinkService parse error: $e');
        }
      },
      onError: (err) {
        debugPrint(' LinkService stream error: $err');
      },
    );
  }

  /// Stop listening to avoid leaks
  static void stopListening() {
    _sub?.cancel();
    _sub = null;
  }

  /// Handle deep link when app is cold-started (from a link tap)
  static Future<String?> getInitialLinkIfAny() async {
    try {
      final appLinks = AppLinks();
      final Uri? initialUri = await appLinks.getInitialLink();

      if (initialUri != null &&
          initialUri.scheme == appScheme &&
          initialUri.host == host) {
        return initialUri.queryParameters['matchId'];
      }
    } catch (e) {
      debugPrint(' Error getting initial link: $e');
    }
    return null;
  }
}
