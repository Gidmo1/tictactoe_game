import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:tictactoe_game/service/auth_service.dart';
import 'package:tictactoe_game/tictactoe.dart';
import 'package:tictactoe_game/service/score_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Clean single implementation of the AuthGate overlay.
class AuthGate extends StatefulWidget {
  final VoidCallback? onLoginSuccess;
  const AuthGate({super.key, this.onLoginSuccess});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class GameAuthOverlay extends StatefulWidget {
  final TicTacToeGame game;

  const GameAuthOverlay({super.key, required this.game});

  @override
  State<GameAuthOverlay> createState() => _GameAuthOverlayState();
}

class _GameAuthOverlayState extends State<GameAuthOverlay>
  with WidgetsBindingObserver {
  bool _loading = false;
  String? _notice;
  StreamSubscription<AuthState>? _subscription;
  Timer? _timeout;
  Timer? _resumeCheck;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _subscription = Supabase.instance.client.auth.onAuthStateChange.listen((
      state,
    ) async {
      if (state.event == AuthChangeEvent.signedIn) {
        _timeout?.cancel();
        final userId = Supabase.instance.client.auth.currentUser?.id;
        if (userId != null) {
          await ScoreService().migrateForFirstAccountSignIn(userId);
        }
        widget.game.refreshActiveProfile();
        widget.game.pendingAuthOnSignedIn?.call();
        widget.game.pendingAuthOnSignedIn = null;
        widget.game.overlays.remove('auth_gate');
      }
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _timeout?.cancel();
    _resumeCheck?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed || !_loading) return;
    _resumeCheck?.cancel();
    _resumeCheck = Timer(const Duration(milliseconds: 800), () {
      if (!mounted || !_loading) return;
      if (Supabase.instance.client.auth.currentUser == null) {
        setState(() {
          _loading = false;
          _notice = 'Sign-in was cancelled.';
        });
      }
    });
  }

  Future<void> _signIn(OAuthProvider provider) async {
    setState(() {
      _loading = true;
      _notice = null;
    });
    try {
      final launched = await Supabase.instance.client.auth.signInWithOAuth(
        provider,
        redirectTo: kIsWeb
            ? Uri.base.origin
            : 'io.supabase.tictactoe://login-callback',
        authScreenLaunchMode: kIsWeb
            ? LaunchMode.platformDefault
            : LaunchMode.inAppBrowserView,
      );
      if (!launched && mounted) {
        setState(() {
          _loading = false;
          _notice = 'Sign-in failed to start. Please try again.';
        });
        return;
      }
      _timeout?.cancel();
      _timeout = Timer(const Duration(minutes: 2), () {
        if (!mounted || !_loading) return;
        setState(() {
          _loading = false;
          _notice = 'Sign-in was cancelled or timed out.';
        });
      });
    } catch (_) {
      if (mounted) {
        setState(() => _notice = 'Could not start sign-in. Please try again.');
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black54,
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 360),
          margin: const EdgeInsets.all(24),
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
          decoration: BoxDecoration(
            color: const Color(0xFF171B24),
            border: Border.all(color: const Color(0xFFD4AF37), width: 2),
            borderRadius: BorderRadius.circular(14),
            boxShadow: const [
              BoxShadow(
                color: Colors.black54,
                blurRadius: 18,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: _loading
              ? const Padding(
                  padding: EdgeInsets.all(30),
                  child: CircularProgressIndicator(color: Color(0xFFD4AF37)),
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'SAVE YOUR PROGRESS',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 19,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Sign in to keep your scores across devices.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                    if (_notice != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        _notice!,
                        style: const TextStyle(color: Colors.orange),
                      ),
                    ],
                    const SizedBox(height: 22),
                    _providerButton(
                      label: 'Continue with Google',
                      color: const Color(0xFF4285F4),
                      icon: FontAwesomeIcons.google,
                      onPressed: () => _signIn(OAuthProvider.google),
                    ),
                    const SizedBox(height: 10),
                    _providerButton(
                      label: 'Continue with Discord',
                      color: const Color(0xFF5865F2),
                      icon: FontAwesomeIcons.discord,
                      onPressed: () => _signIn(OAuthProvider.discord),
                    ),
                    const SizedBox(height: 10),
                    TextButton(
                      onPressed: () => widget.game.overlays.remove('auth_gate'),
                      child: const Text(
                        'Continue as guest',
                        style: TextStyle(color: Colors.white70),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _providerButton({
    required String label,
    required Color color,
    required FaIconData icon,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: FaIcon(icon, size: 18),
        label: Text(label),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        ),
      ),
    );
  }
}

class _AuthGateState extends State<AuthGate> {
  bool _loading = false;
  String? _notice;

  Future<void> _signIn(Future<dynamic> Function() action) async {
    setState(() {
      _loading = true;
      _notice = null;
    });
    try {
      final credential = await action();
      if (credential?.user != null) {
        widget.onLoginSuccess?.call();
        if (mounted) Navigator.of(context).pop();
        return;
      }
      setState(() => _notice = 'Sign-in cancelled');
    } catch (_) {
      setState(() => _notice = 'Sign-in failed. Please try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black54,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480, maxHeight: 520),
          child: _loading
              ? const CircularProgressIndicator(color: Colors.white)
              : Container(
                  decoration: BoxDecoration(
                    image: const DecorationImage(
                      image: AssetImage(
                        'assets/images/confirmation_overlay.png',
                      ),
                      fit: BoxFit.cover,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 18,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(height: 6),
                      const Text(
                        'Sign in so you won\'t lose your scores',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          shadows: [
                            Shadow(
                              blurRadius: 3,
                              color: Colors.black,
                              offset: Offset(0, 1),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                      if (_notice != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8.0),
                          child: Text(
                            _notice!,
                            style: const TextStyle(color: Colors.orange),
                          ),
                        ),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.black,
                          minimumSize: const Size(260, 50),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.zero,
                          ),
                        ),
                        icon: FaIcon(
                          FontAwesomeIcons.google,
                          size: 20,
                          color: const Color(0xFFDB4437),
                        ),
                        label: const Text('Sign in with Google'),
                        onPressed: () =>
                            _signIn(() => AuthHelper().signInWithGoogle()),
                      ),
                      const SizedBox(height: 10),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF5865F2),
                          foregroundColor: Colors.white,
                          minimumSize: const Size(260, 50),
                          shape: const RoundedRectangleBorder(
                            borderRadius: BorderRadius.zero,
                          ),
                        ),
                        icon: const FaIcon(FontAwesomeIcons.discord, size: 20),
                        label: const Text('Sign in with Discord'),
                        onPressed: () =>
                            _signIn(() => AuthHelper().signInWithDiscord()),
                      ),
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                        },
                        child: const Text(
                          'Continue as Guest',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}

// trailing duplicate block removed
