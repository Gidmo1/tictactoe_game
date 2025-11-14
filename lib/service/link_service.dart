import 'dart:async';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:app_links/app_links.dart';

class LinkService {
  static const String appScheme = 'tictactoe';
  static const String host = 'join'; // used for deep link detection
  static const String webDomain = 'https://tictactoeapp.com'; // fallback site

  // Generate a custom invite link for your game
  static String createInviteLink(String matchId) {
    return '$appScheme://$host?matchId=$matchId';
  }

  // Open a link directly
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

  // Stream subscription for deep links
  static StreamSubscription<Uri>? _sub;

  // Start listening for deep links (when the app is already open)
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

  // Stop listening to avoid leaks
  static void stopListening() {
    _sub?.cancel();
    _sub = null;
  }

  // Handle deep link when app is cold-started (from a link tap)
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
