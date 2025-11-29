import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:tictactoe_game/service/auth_service.dart';

/// Clean single implementation of the AuthGate overlay.
class AuthGate extends StatefulWidget {
  final VoidCallback? onLoginSuccess;
  const AuthGate({super.key, this.onLoginSuccess});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool _loading = false;
  String? _notice;

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
                        onPressed: () async {
                          setState(() {
                            _loading = true;
                            _notice = null;
                          });
                          try {
                            final cred = await AuthHelper().signInWithGoogle();
                            if (cred != null && cred.user != null) {
                              widget.onLoginSuccess?.call();
                              if (mounted) Navigator.of(context).pop();
                              return;
                            }
                            setState(() => _notice = 'Sign-in cancelled');
                          } catch (e) {
                            setState(
                              () =>
                                  _notice = 'Sign-in failed. Please try again.',
                            );
                          } finally {
                            if (mounted) setState(() => _loading = false);
                          }
                        },
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
