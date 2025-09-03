import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

class Firebaseinit {
  Future<void> initFirebase() async {
    FirebaseApp app = await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    print('Initialized default app $app');
  }
}
