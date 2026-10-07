import 'package:firebase_auth/firebase_auth.dart';

abstract class AuthService {
  /// 익명 로그인 후 uid. 이미 로그인돼 있으면 그 uid.
  Future<String> signInAnonymously();
}

class FirebaseAuthService implements AuthService {
  @override
  Future<String> signInAnonymously() async {
    final auth = FirebaseAuth.instance;
    final user = auth.currentUser ?? (await auth.signInAnonymously()).user!;
    return user.uid;
  }
}
