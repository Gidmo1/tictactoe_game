import 'supabase_compat.dart' as fb;
import 'package:supabase_flutter/supabase_flutter.dart';

Future<fb.UserCredential?> signInWithGoogleImpl() async {
  await Supabase.instance.client.auth.signInWithOAuth(
    OAuthProvider.google,
    redirectTo: Uri.base.origin,
  );
  return fb.UserCredential(user: fb.FirebaseAuth.instance.currentUser);
}

Future<void> signOutImpl() async {
  try {
    await fb.FirebaseAuth.instance.signOut();
  } catch (_) {}
}
