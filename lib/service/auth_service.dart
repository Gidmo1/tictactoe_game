import 'package:flutter/foundation.dart';
import 'supabase_compat.dart' as fb;

// Platform specific implementations. Use the web impl when building for
// web; for other platforms the stub will be used which keeps the app
// buildable until native sign-in is implemented/configured.
import 'auth_impl_stub.dart'
    if (dart.library.io) 'auth_impl_mobile.dart'
    if (dart.library.html) 'auth_impl_web.dart'
    as platform_impl;

class AuthHelper {
  bool _providerFlowInProgress = false;

  /// Sign in with Google through Supabase Auth.
  /// Returns null if the user cancelled the flow.
  Future<fb.UserCredential?> signInWithGoogle() async {
    // Prevent concurrent provider sign-in flows which can confuse the native broker.
    if (_providerFlowInProgress) {
      debugPrint(
        'AuthHelper.signInWithGoogle: provider flow already in progress',
      );
      return null;
    }
    _providerFlowInProgress = true;
    try {
      return await platform_impl.signInWithGoogleImpl();
    } catch (e, stack) {
      debugPrint('AuthHelper.signInWithGoogle: platform impl threw: $e');
      debugPrintStack(stackTrace: stack);
      return null;
    } finally {
      _providerFlowInProgress = false;
    }
  }

  /// Sign out method
  Future<void> signOut() async {
    try {
      await platform_impl.signOutImpl();
    } catch (e) {
      debugPrint('Sign-out failed: $e');
    }
  }
}
