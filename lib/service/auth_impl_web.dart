import 'package:firebase_auth/firebase_auth.dart' as fb;

Future<fb.UserCredential?> signInWithGoogleImpl() async {
  final provider = fb.GoogleAuthProvider();
  return await fb.FirebaseAuth.instance.signInWithPopup(provider);
}

Future<void> signOutImpl() async {
  try {
    await fb.FirebaseAuth.instance.signOut();
  } catch (_) {}
}
