import 'package:flutter/foundation.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:cloud_functions/cloud_functions.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthHelper {
  final FirebaseFunctions functions = FirebaseFunctions.instanceFor(
    region: 'us-central1',
  );

  Future<void> signInWithFacebook() async {
    try {
      final LoginResult result = await FacebookAuth.instance.login(
        permissions: ['public_profile'],
      );
      if (result.status == LoginStatus.success && result.accessToken != null) {
        final accessToken = result.accessToken!.token;
        final facebookCredential = fb.FacebookAuthProvider.credential(
          accessToken,
        );
        await fb.FirebaseAuth.instance.signInWithCredential(facebookCredential);

        // After sign-in, try to move guest data
        try {
          final prefs = await SharedPreferences.getInstance();
          final guestId = prefs.getString('guest_id');
          if (guestId != null && guestId.startsWith('guest_')) {
            try {
              final callable = functions.httpsCallable('migrateGuestToUser');
              await callable.call({'guestId': guestId});
              // Remove stored guest id after successful migration.
              await prefs.remove('guest_id');
            } catch (e) {
              debugPrint('migrateGuestToUser failed: $e');
            }
          }
        } catch (e) {
          debugPrint('Guest migration attempt failed locally: $e');
        }
      } else {
        debugPrint('Facebook login cancelled or failed: ${result.status}');
      }
    } catch (e) {
      debugPrint('Error during Facebook sign-in: $e');
      rethrow;
    }
  }
}
