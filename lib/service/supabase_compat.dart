import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

class FirebaseException implements Exception {
  final String code;
  final String? message;
  FirebaseException({this.code = 'supabase_error', this.message});

  @override
  String toString() => message ?? code;
}

class FirebaseAuthException extends FirebaseException {
  FirebaseAuthException({super.code, super.message});
}

class UserInfo {
  final String providerId;
  const UserInfo(this.providerId);
}

class User {
  final String uid;
  final String? displayName;
  final String? email;
  final bool isAnonymous;
  final List<UserInfo> providerData;

  const User({
    required this.uid,
    this.displayName,
    this.email,
    this.isAnonymous = false,
    this.providerData = const [],
  });

  Future<String?> getIdToken([bool forceRefresh = false]) async => null;
  Future<void> reload() async {}
}

class UserCredential {
  final User? user;
  const UserCredential({this.user});
}

class GoogleAuthProvider {}

class FirebaseAuth {
  FirebaseAuth._();
  static final instance = FirebaseAuth._();
  User? get currentUser {
    final user = supabase.Supabase.instance.client.auth.currentUser;
    if (user == null) return null;
    return User(
      uid: user.id,
      email: user.email,
      displayName: user.userMetadata?['name'] as String?,
      providerData: [
        UserInfo(user.appMetadata['provider'] as String? ?? 'email'),
      ],
    );
  }

  Stream<User?> authStateChanges() => supabase
      .Supabase
      .instance
      .client
      .auth
      .onAuthStateChange
      .map((event) => currentUser);

  Stream<User?> idTokenChanges() => authStateChanges();
  Future<void> signOut() => supabase.Supabase.instance.client.auth.signOut();
  Future<UserCredential> signInWithProvider(
    GoogleAuthProvider provider,
  ) async => const UserCredential();
  Future<UserCredential> signInWithPopup(GoogleAuthProvider provider) async =>
      const UserCredential();
}

class Timestamp {
  final DateTime _value;
  Timestamp.fromDate(this._value);
  DateTime toDate() => _value;
}

class FieldValue {
  final dynamic value;
  const FieldValue._(this.value);
  static FieldValue arrayUnion(List<dynamic> values) => FieldValue._(values);
  static FieldValue serverTimestamp() => FieldValue._(DateTime.now().toUtc());
}

class DocumentSnapshot<T> {
  final String id;
  final Map<String, dynamic>? _value;
  DocumentSnapshot(this.id, this._value);
  bool get exists => _value != null;
  T? data() => _value as T?;
}

class QuerySnapshot<T> {
  final List<DocumentSnapshot<T>> docs;
  const QuerySnapshot(this.docs);

  bool get exists => docs.any((doc) => doc.exists);
  T? data() => docs.isEmpty ? null : docs.first.data();
}

class DocumentReference<T> {
  final String table;
  final String id;
  const DocumentReference(this.table, this.id);

  Future<DocumentSnapshot<T>> get() async {
    final data = await supabase.Supabase.instance.client
        .from(table)
        .select()
        .eq('id', id)
        .maybeSingle();
    return DocumentSnapshot<T>(id, data);
  }

  Future<void> set(Map<String, dynamic> data, {bool merge = false}) async {
    await supabase.Supabase.instance.client.from(table).upsert({
      'id': id,
      ...data,
    });
  }

  Future<void> update(Map<String, dynamic> data) async {
    await supabase.Supabase.instance.client
        .from(table)
        .update(data)
        .eq('id', id);
  }

  Future<void> delete() async {
    await supabase.Supabase.instance.client.from(table).delete().eq('id', id);
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> snapshots() async* {
    final snapshot = await get();
    yield DocumentSnapshot<Map<String, dynamic>>(
      snapshot.id,
      snapshot.data() as Map<String, dynamic>?,
    );
  }

  CollectionReference<T> collection(String name) =>
      CollectionReference<T>('$table/$id/$name');
}

class CollectionReference<T> {
  final String table;
  const CollectionReference(this.table);
  DocumentReference<T> doc(String id) => DocumentReference<T>(table, id);

  Future<QuerySnapshot<T>> get() async {
    final rows = await supabase.Supabase.instance.client.from(table).select();
    return QuerySnapshot<T>([
      for (final row in rows)
        DocumentSnapshot<T>(row['id']?.toString() ?? '', row),
    ]);
  }

  Stream<QuerySnapshot<T>> snapshots() async* {
    yield await get();
  }

  CollectionReference<T> orderBy(String field, {bool descending = false}) =>
      this;
  CollectionReference<T> where(
    String field, {
    dynamic isEqualTo,
    dynamic isGreaterThan,
  }) => this;
  CollectionReference<T> limit(int count) => this;
  CollectionReference<T> collection(String name) =>
      CollectionReference<T>('$table/$name');
}

class FirebaseFirestore {
  FirebaseFirestore._();
  static final instance = FirebaseFirestore._();
  CollectionReference<T> collection<T>(String name) =>
      CollectionReference<T>(name);
}

class FirebaseFunctionsException implements Exception {
  final String code;
  final String? message;
  FirebaseFunctionsException({this.code = 'supabase_error', this.message});
}

class CallableResult {
  final dynamic data;
  const CallableResult(this.data);
}

class HttpsCallable {
  final String name;
  const HttpsCallable(this.name);
  Future<CallableResult> call([dynamic parameters]) async {
    throw FirebaseFunctionsException(
      code: 'not_migrated',
      message: 'Supabase Edge Function "$name" is not configured yet.',
    );
  }
}

class FirebaseFunctions {
  FirebaseFunctions._();
  static final instance = FirebaseFunctions._();
  static FirebaseFunctions instanceFor({String? region}) => instance;
  HttpsCallable httpsCallable(String name) => HttpsCallable(name);
}

class FirebaseApp {
  final FirebaseAppOptions options = const FirebaseAppOptions('supabase');
}

class FirebaseAppOptions {
  final String projectId;
  const FirebaseAppOptions(this.projectId);
}

class Firebase {
  static FirebaseApp app() => FirebaseApp();
}
