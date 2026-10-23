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
}
