import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;

/// Stub implementation used on platforms that don't have a native
/// Google sign-in implementation configured. This ensures the app
/// remains buildable while mobile sign-in is implemented later.
Future<fb.UserCredential?> signInWithGoogleImpl() async {
  debugPrint('signInWithGoogleImpl: stub called (platform not configured)');
  return null;
}

Future<void> signOutImpl() async {
  debugPrint('signOutImpl: stub called (no-op)');
}
