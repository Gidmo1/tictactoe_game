import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;

/// Mobile implementation using Firebase's signInWithProvider.
/// This uses the Firebase authentication flow which delegates to the native platform.
Future<fb.UserCredential?> signInWithGoogleImpl() async {
  try {
    await Future.delayed(const Duration(milliseconds: 200));

    debugPrint('auth_impl_mobile: attempting signInWithProvider');

    final provider = fb.GoogleAuthProvider();
    final result = await fb.FirebaseAuth.instance.signInWithProvider(provider);
    debugPrint('auth_impl_mobile: sign-in success, uid=${result.user?.uid}');
    return result;
  } on fb.FirebaseAuthException catch (e) {
    debugPrint(
      'auth_impl_mobile: Firebase error code=${e.code} message=${e.message}',
    );

    // Log detailed error info for debugging
    debugPrint('auth_impl_mobile: Full error: $e');

    debugPrintStack(stackTrace: StackTrace.current);
    return null;
  } catch (e) {
    debugPrint('auth_impl_mobile: error: $e');
    debugPrintStack(stackTrace: StackTrace.current);
    return null;
  }
}

Future<void> signOutImpl() async {
  try {
    await fb.FirebaseAuth.instance.signOut();
  } catch (_) {}
}
