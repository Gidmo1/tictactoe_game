import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class AuthGate extends StatefulWidget {
  final VoidCallback? onLoginSuccess;
  const AuthGate({super.key, this.onLoginSuccess});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool _loading = false;

  Future<void> _signInWithFacebook() async {
    setState(() {
      _loading = true;
    });

    try {
      final LoginResult result = await FacebookAuth.instance.login(
        permissions: ['public_profile'],
      );

      if (result.status == LoginStatus.success && result.accessToken != null) {
        final accessToken = result.accessToken!.token;
        final facebookCredential = FacebookAuthProvider.credential(accessToken);
        await FirebaseAuth.instance.signInWithCredential(facebookCredential);

        // show success then close

        // Give UI a second to show success
        await Future.delayed(const Duration(seconds: 1));

        if (mounted) {
          // Close the auth gate dialog/screen
          Navigator.of(context).pop();

          // Notify parent (if any)
          widget.onLoginSuccess?.call();

          // Navigate to Competition screen inside Flame router
          try {} catch (e) {
            debugPrint('Could not navigate to competition: $e');
          }
        }
      } else {
        debugPrint('Facebook login failed: ${result.status}');
      }
    } catch (e) {
      debugPrint('Error during Facebook login: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Center(
        child: _loading
            ? const CircularProgressIndicator(color: Colors.white)
            : Container(
                width: 420,
                height: 420,
                decoration: BoxDecoration(
                  image: const DecorationImage(
                    image: AssetImage('assets/images/confirmation_overlay.png'),
                    fit: BoxFit.cover,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 16),
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
                    const SizedBox(height: 24),
                    // Buttons row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ElevatedButton.icon(
                          onPressed: _signInWithFacebook,
                          icon: const FaIcon(
                            FontAwesomeIcons.facebook,
                            color: Colors.white,
                          ),
                          label: const Text('Facebook'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF3b5998),
                          ),
                        ),
                        const SizedBox(width: 16),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: () {
                        // Allow closing without signing in (continue as guest)
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
    );
  }
}
