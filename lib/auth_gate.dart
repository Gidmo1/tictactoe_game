import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
// removed unused imports

class AuthGate extends StatefulWidget {
  final VoidCallback? onLoginSuccess;
  const AuthGate({super.key, this.onLoginSuccess});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool _loading = false;
  String? _signedInName;

  Future<void> _signInWithFacebook() async {
    setState(() {
      _loading = true;
      _signedInName = null;
    });

    try {
      final LoginResult result = await FacebookAuth.instance.login(
        permissions: ['public_profile'],
      );

      if (result.status == LoginStatus.success && result.accessToken != null) {
        final accessToken = result.accessToken!.token;
        final facebookCredential = FacebookAuthProvider.credential(accessToken);
        final userCred = await FirebaseAuth.instance.signInWithCredential(
          facebookCredential,
        );

        final displayName =
            userCred.user?.displayName ?? userCred.user?.email ?? 'Unknown';

        setState(() {
          _signedInName = displayName;
        });

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
      body: Stack(
        children: [
          // Fullscreen background
          SizedBox.expand(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Color.fromARGB(255, 21, 59, 23),
                    Color.fromARGB(255, 21, 59, 23),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
          ),

          // Center Facebook login button
          Center(
            child: _loading
                ? const CircularProgressIndicator(color: Colors.white)
                : GestureDetector(
                    onTap: _signInWithFacebook,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        vertical: 16,
                        horizontal: 24,
                      ),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [
                            Color.fromARGB(255, 8, 77, 203),
                            Color.fromARGB(255, 8, 77, 203),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: const Color.fromARGB(
                              255,
                              8,
                              77,
                              203,
                            ).withOpacity(0.7),
                            blurRadius: 16,
                            spreadRadius: 2,
                            offset: const Offset(0, 0),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          FaIcon(
                            FontAwesomeIcons.facebook,
                            color: Colors.white,
                            size: 28,
                          ),
                          SizedBox(width: 16),
                          Text(
                            'Continue with Facebook',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              shadows: [
                                Shadow(
                                  color: Color.fromARGB(255, 8, 77, 203),
                                  blurRadius: 8,
                                  offset: Offset(0, 2),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
          ),

          // Signed-in message
          if (_signedInName != null)
            Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 32),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.check_circle,
                      color: Colors.green,
                      size: 28,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Successfully signed in as $_signedInName',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        shadows: [
                          Shadow(
                            color: Colors.black,
                            blurRadius: 8,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
