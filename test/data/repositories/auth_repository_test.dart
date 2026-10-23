import 'package:flutter_test/flutter_test.dart';
import 'package:topsoldier/data/repositories/auth_repository.dart';
import 'package:topsoldier/data/services/auth_service.dart';

import '../../fakes.dart';

void main() {
  test('linking google keeps the uid', () async {
    final repo = AuthRepository(FakeAuthService('anon'));
    expect(await repo.signIn(), 'anon');
    expect(await repo.linkGoogle(), GoogleLink.linked);
    expect(repo.uid, 'anon');
    expect(repo.googleEmail, 'me@gmail.com');
  });

  test('switching to an existing google account changes the uid', () async {
    final repo = AuthRepository(
      FakeAuthService('anon', linkResult: GoogleLink.exists),
    );
    await repo.signIn();
    expect(await repo.linkGoogle(), GoogleLink.exists);
    expect(repo.uid, 'anon');
    await repo.switchToGoogle();
    expect(repo.uid, 'google-uid');
  });

  test('two sign-ins at once (first run) create only one account', () async {
    final auth = _CountingAuth();
    final repo = AuthRepository(auth);
    final both = await Future.wait([repo.signIn(), repo.signIn()]);
    expect(both, ['u1', 'u1']);
    expect(auth.calls, 1);
  });

  test('a failed sign-in can be retried', () async {
    final auth = FlakyAuthService('u', failures: 1);
    final repo = AuthRepository(auth);
    await expectLater(repo.signIn(), throwsException);
    expect(await repo.signIn(), 'u');
  });
}

class _CountingAuth with NoGoogleAuth implements AuthService {
  int calls = 0;

  @override
  Future<String> signInAnonymously() async {
    calls++;
    await Future<void>.delayed(Duration.zero);
    return 'u$calls';
  }
}
