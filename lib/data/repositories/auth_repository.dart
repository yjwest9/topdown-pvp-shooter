import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/auth_service.dart';

final authRepositoryProvider = Provider(
  (ref) => AuthRepository(FirebaseAuthService()),
);

class AuthRepository {
  AuthRepository(this._auth, {Random? random}) : _random = random ?? Random();

  final AuthService _auth;
  final Random _random;

  String? uid;

  /// 임시 닉네임 "Soldier" + 4자리. 닉네임 입력은 나중.
  late final String nickname = 'Soldier${1000 + _random.nextInt(9000)}';

  Future<String> signIn() async => uid ??= await _auth.signInAnonymously();

  /// 연결된 구글 이메일. 연결 안 됐으면 null.
  String? get googleEmail => _auth.googleEmail;

  /// 지금 계정에 구글을 연결한다(uid 그대로).
  Future<GoogleLink> linkGoogle() => _auth.linkGoogle();

  /// 이미 다른 계정에 붙은 구글로 로그인을 바꾼다. 이후 uid는 새 계정 것.
  Future<void> switchToGoogle() async => uid = await _auth.switchToGoogle();
}
