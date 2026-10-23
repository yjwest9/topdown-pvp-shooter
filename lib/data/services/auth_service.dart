import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// 구글 연결 시도 결과. [exists]는 그 구글 계정이 이미 다른 uid에 붙어 있다는 뜻.
enum GoogleLink { linked, exists, cancelled }

abstract class AuthService {
  /// 익명 로그인 후 uid. 이미 로그인돼 있으면 그 uid.
  Future<String> signInAnonymously();

  /// 지금 계정에 연결된 구글 이메일. 연결 안 됐으면 null.
  String? get googleEmail;

  /// 지금 계정(uid 그대로)에 구글 계정을 연결한다.
  Future<GoogleLink> linkGoogle();

  /// [linkGoogle]이 [GoogleLink.exists]였을 때, 그 구글 계정으로 로그인을 바꾼다. 새 uid.
  Future<String> switchToGoogle();
}

class FirebaseAuthService implements AuthService {
  AuthCredential? _pending;
  bool _googleReady = false;

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

  @override
  String? get googleEmail {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;
    for (final p in user.providerData) {
      if (p.providerId == 'google.com') return p.email ?? '';
    }
    return null;
  }

  @override
  Future<GoogleLink> linkGoogle() async {
    final user = FirebaseAuth.instance.currentUser!;
    _pending = null;
    try {
      if (kIsWeb) {
        await user.linkWithPopup(GoogleAuthProvider());
      } else {
        final credential = await _googleCredential();
        if (credential == null) return GoogleLink.cancelled;
        await user.linkWithCredential(credential);
      }
      return GoogleLink.linked;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'popup-closed-by-user' ||
          e.code == 'cancelled-popup-request') {
        return GoogleLink.cancelled;
      }
      if (e.code == 'credential-already-in-use' && e.credential != null) {
        _pending = e.credential;
        return GoogleLink.exists;
      }
      rethrow;
    }
  }

  @override
  Future<String> switchToGoogle() async {
    final credential = _pending!;
    _pending = null;
    return (await FirebaseAuth.instance.signInWithCredential(credential))
        .user!
        .uid;
  }

  /// 안드로이드: 구글 계정 선택 창 → Firebase 자격 증명. 사용자가 닫으면 null.
  Future<AuthCredential?> _googleCredential() async {
    final google = GoogleSignIn.instance;
    if (!_googleReady) {
      await google.initialize();
      _googleReady = true;
    }
    try {
      final account = await google.authenticate();
      return GoogleAuthProvider.credential(
        idToken: account.authentication.idToken,
      );
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) return null;
      rethrow;
    }
  }
}
