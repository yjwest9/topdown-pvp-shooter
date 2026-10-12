import 'package:flutter_test/flutter_test.dart';
import 'package:topsoldier/data/repositories/profile_repository.dart';

import '../../fakes.dart';

void main() {
  test('create → watch shows a fresh level 1 profile', () async {
    final db = FakeRtdbService();
    final repo = ProfileRepository(db);
    expect(await repo.watch('u').first, isNull);

    await repo.create('u', '솔저');

    final p = (await repo.watch('u').first)!;
    expect((p.nickname, p.level, p.exp, p.gold, p.diamond), ('솔저', 1, 0, 0, 0));
    expect(await db.get('users/u/createdAt'), db.serverTime);
  });

  test('the same matchId is added only once', () async {
    final repo = ProfileRepository(FakeRtdbService());
    await repo.create('u', 'A');

    final first = await repo.applyMatch(
      'u',
      'room1-100',
      (p) => p.copyWith(gold: p.gold + 5000, matches: p.matches + 1),
    );
    final again = await repo.applyMatch(
      'u',
      'room1-100',
      (p) => p.copyWith(gold: p.gold + 5000, matches: p.matches + 1),
    );

    expect(first!.before.gold, 0);
    expect(first.after.gold, 5000);
    expect(again, isNull);
    final p = (await repo.watch('u').first)!;
    expect((p.gold, p.matches), (5000, 1));

    await repo.applyMatch(
      'u',
      'room1-200',
      (p) => p.copyWith(gold: p.gold + 1),
    );
    expect((await repo.watch('u').first)!.gold, 5001); // 다른 매치는 더해짐
  });

  test('no profile yet → nothing is written', () async {
    final db = FakeRtdbService();
    final r = await ProfileRepository(db)
        .applyMatch('u', 'm', (p) => p.copyWith(gold: 1));
    expect(r, isNull);
    expect(await db.get('users/u'), isNull);
  });

  test('nickname change keeps the rest', () async {
    final repo = ProfileRepository(FakeRtdbService());
    await repo.create('u', 'A');
    await repo.applyMatch('u', 'm', (p) => p.copyWith(gold: 10));
    await repo.setNickname('u', '새이름');
    final p = (await repo.watch('u').first)!;
    expect((p.nickname, p.gold), ('새이름', 10));
  });
}
