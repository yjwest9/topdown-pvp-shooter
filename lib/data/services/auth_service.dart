import 'package:firebase_auth/firebase_auth.dart';

abstract class AuthService {
  /// 익명 로그인 후 uid. 이미 로그인돼 있으면 그 uid.
  Future<String> signInAnonymously();
}

class FirebaseAuthService implements AuthService {
  @override
  Future<String> signInAnonymously() async {
    final auth = FirebaseAuth.instance;
    final saved = auth.currentUser;
    if (saved != null) {
      // 기기에 저장된 계정이 서버에 없으면(에뮬레이터 재시작, 계정 삭제) 토큰 갱신만
      // 계속 재시도하며 DB 요청이 멈춘다. 서버에 확인하고 없으면 새로 로그인한다.
      try {
        await saved.reload();
        return saved.uid;
      } on FirebaseAuthException {
        await auth.signOut();
      }
    }
    return (await auth.signInAnonymously()).user!.uid;
  }
}
