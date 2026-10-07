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
}
