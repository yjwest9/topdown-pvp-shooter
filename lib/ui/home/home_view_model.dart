import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/holiday.dart';
import '../../data/models/profile.dart';
import '../../data/repositories/ad_repository.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/event_repository.dart';
import '../../data/repositories/profile_repository.dart';
import '../../data/repositories/room_repository.dart';
import '../../rules/balance.dart';
import '../../rules/profile.dart';

/// 오늘이 공휴일이면 그 공휴일(매치 보상 2배 이벤트). 앱 실행 중 한 번만 묻는다.
final holidayProvider = FutureProvider<Holiday?>(
  (ref) => ref.read(eventRepositoryProvider).todayHoliday(DateTime.now()),
);

class HomeState {
  const HomeState({
    required this.profile,
    this.needsNickname = false,
    this.holiday,
  });

  /// 아직 못 읽었거나(로딩·오프라인) 없으면 임시 닉네임의 빈 프로필.
  final Profile profile;

  /// 첫 실행: 프로필이 없다 → 닉네임 입력.
  final bool needsNickname;
  final Holiday? holiday;

  /// "공휴일 보상 2배!" 띠.
  bool get showEventBanner => holiday != null;

  /// 경험치 바 0~1.
  double get expRatio => profile.exp / expToNext(profile.level);

  /// 프로필 카드(전적). 친선전 포함.
  List<(String, String)> get record {
    final p = profile;
    return [
      ('레벨', 'Lv.${p.level}  (${p.exp} / ${expToNext(p.level)} EXP)'),
      ('총 판수', '${p.matches}'),
      ('승 / 패', '${p.wins} / ${p.matches - p.wins}'),
      ('승률', '${(winRate(wins: p.wins, matches: p.matches) * 100).round()}%'),
      ('킬 / 데스', '${p.kills} / ${p.deaths}'),
      ('K/D', kdRatio(kills: p.kills, deaths: p.deaths).toStringAsFixed(2)),
    ];
  }
}

final homeProvider = NotifierProvider<HomeViewModel, HomeState>(
  HomeViewModel.new,
);

class HomeViewModel extends Notifier<HomeState> {
  AuthRepository get _auth => ref.read(authRepositoryProvider);

  /// 봇전 방(기기 안 메모리 DB, 로그인 없음). 이미 시작한 상태로 온다.
  Future<({RoomRepository rooms, String code})> botRoom() =>
      RoomRepository.botRoom(
        uid: 'me',
        name: myNickname(ref),
        durationMs: matchDurationMs,
        character: myCharacter(ref),
      );

  /// 닉네임 입력 창의 기본값.
  String get defaultNickname => _auth.nickname;

  bool _granting = false;
  bool _adPreloaded = false;

  @override
  HomeState build() {
    // 상점에서 바로 누를 수 있게 광고를 미리 불러 둔다(매치 밖, decisions 10장).
    if (!_adPreloaded) {
      _adPreloaded = true;
      unawaited(ref.read(adRepositoryProvider).load());
    }
    final p = ref.watch(profileProvider);
    // 새 유저·기존 유저 모두 로드아웃이 없으면 기본 무기, 기본 병사가 없으면 기본 병사 지급
    // (decisions 6장·8장). 둘 다 이미 있으면 저장소가 아무것도 안 한다.
    if (p.value case final profile?
        when (!profile.hasLoadout ||
                !profile.characters.containsKey(basicSoldier.id)) &&
            !_granting) {
      _granting = true;
      Future.microtask(() async {
        try {
          final repo = ref.read(profileRepositoryProvider);
          final uid = await _auth.signIn();
          await repo.grantStarter(
            uid,
            primary: startingPrimary.id,
            secondary: startingSecondary.id,
          );
          await repo.grantStarterCharacter(uid, id: basicSoldier.id);
        } finally {
          _granting = false;
        }
      });
    }
    return HomeState(
      profile: p.value ?? Profile(nickname: _auth.nickname),
      needsNickname: p.hasValue && p.value == null,
      holiday: ref.watch(holidayProvider).value,
    );
  }

  /// 처음이면 프로필을 만들고, 있으면 닉네임만 바꾼다. 안 되면 이유.
  Future<String?> saveNickname(String input) async {
    final name = input.trim();
    final error = nicknameError(name);
    if (error != null) return error;
    try {
      final uid = await _auth.signIn();
      final repo = ref.read(profileRepositoryProvider);
      if (state.needsNickname) {
        await repo.create(uid, name);
      } else {
        await repo.setNickname(uid, name);
      }
      return null;
    } catch (e) {
      return '저장하지 못했습니다: $e';
    }
  }
}
