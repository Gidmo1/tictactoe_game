import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:cloud_functions/cloud_functions.dart';

// Platform specific implementations. Use the web impl when building for
// web; for other platforms the stub will be used which keeps the app
// buildable until native sign-in is implemented/configured.
import 'auth_impl_stub.dart'
    if (dart.library.io) 'auth_impl_mobile.dart'
    if (dart.library.html) 'auth_impl_web.dart'
    as platform_impl;

class AuthHelper {
  final FirebaseFunctions functions = FirebaseFunctions.instanceFor(
    region: 'us-central1',
  );
  bool _providerFlowInProgress = false;

  /// Sign in with Google and return the Firebase [UserCredential].
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
      final current = fb.FirebaseAuth.instance.currentUser;

      // If the user is anonymous, perform a provider sign-in using the
      // platform implementation and then migrate guest data from the
      // anonymous id to the authenticated uid. This approach avoids
      // directly depending on `google_sign_in` here and centralizes the
      // provider flow in the platform impl.
      if (current != null && current.isAnonymous) {
        debugPrint(
          'AuthHelper: anonymous user detected, performing provider sign-in and migrating guest data',
        );
        final result = await platform_impl.signInWithGoogleImpl();
        if (result == null) {
          debugPrint(
            'AuthHelper: provider sign-in returned null (cancelled or failed)',
          );
          return null;
        }
        try {
          final guestId = current.uid;
          final callable = functions.httpsCallable('migrateGuestToUser');
          await callable.call({'guestId': guestId});
          debugPrint(
            'AuthHelper: migrateGuestToUser callable invoked for guestId=$guestId',
          );
        } catch (mErr) {
          debugPrint('AuthHelper: migrateGuestToUser callable failed: $mErr');
        }
        return result;
      }

      // Not anonymous (or anonymous linking failed) — fall back to platform impl.
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
