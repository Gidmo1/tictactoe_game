import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_compat.dart' as fb;

Future<fb.UserCredential?> signInWithGoogleImpl() async {
  try {
    await Supabase.instance.client.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: 'io.supabase.tictactoe://login-callback',
      authScreenLaunchMode: LaunchMode.inAppBrowserView,
    );
    return fb.UserCredential(user: fb.FirebaseAuth.instance.currentUser);
  } catch (e) {
    debugPrint('Supabase Google sign-in error: $e');
    return null;
  }
}

Future<void> signOutImpl() async {
  try {
    await fb.FirebaseAuth.instance.signOut();
  } catch (_) {}
}
