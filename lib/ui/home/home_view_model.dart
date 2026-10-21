import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/holiday.dart';
import '../../data/models/match_stats.dart';
import '../../data/models/profile.dart';
import '../../data/repositories/ad_repository.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/event_repository.dart';
import '../../data/repositories/profile_repository.dart';
import '../../data/repositories/room_repository.dart';
import '../../rules/active_match.dart';
import '../../rules/balance.dart';
import '../../rules/match.dart';
import '../../rules/profile.dart';
import '../../rules/rewards.dart';
import '../format.dart';
import '../result/result_view_model.dart';

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

/// 지난 대전을 끝내지 않고 나가 패배로 기록했을 때 홈이 안내를 한 번 띄운다.
final forfeitNoticeProvider = NotifierProvider<ForfeitNotice, bool>(
  ForfeitNotice.new,
);

class ForfeitNotice extends Notifier<bool> {
  @override
  bool build() => false;

  void show() => state = true;
  void clear() => state = false;
}

final homeProvider = NotifierProvider<HomeViewModel, HomeState>(
  HomeViewModel.new,
);

class HomeViewModel extends Notifier<HomeState> {
  AuthRepository get _auth => ref.read(authRepositoryProvider);

  /// 봇전 방(기기 안 메모리 DB, 로그인 없음). 이미 시작한 상태로 온다.
  Future<({RoomRepository rooms, String code})> botRoom({
    String map = 'duel',
    int teamSize = 1,
  }) => RoomRepository.botRoom(
    uid: 'me',
    name: myNickname(ref),
    durationMs: matchDurationMs,
    character: myCharacter(ref),
    map: map,
    teamSize: teamSize,
  );

  /// 닉네임 입력 창의 기본값.
  String get defaultNickname => _auth.nickname;

  bool _granting = false;
  bool _settling = false;
  bool _adPreloaded = false;

  @override
  HomeState build() {
    // 상점에서 바로 누를 수 있게 광고를 미리 불러 둔다(매치 밖, decisions 10장).
    if (!_adPreloaded) {
      _adPreloaded = true;
      unawaited(ref.read(adRepositoryProvider).load());
    }
    final p = ref.watch(profileProvider);
    // 오프라인 첫 실행 등으로 프로필을 못 읽었으면 연결이 돌아올 때까지 계속 다시 시도한다
    // (Riverpod 자체 재시도는 몇 번 뒤 포기한다). 돌아오면 프로필이 없을 때 닉네임 입력 창이 뜬다.
    if (p.hasError) {
      final retry = Timer(profileRetry, () => ref.invalidate(profileProvider));
      ref.onDispose(retry.cancel);
    }
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
    // 빠른 대전 도중 강제 종료로 남은 표시가 있으면 그 판을 패배로 한 번 저장한다(decisions 9장).
    if (p.value case final profile?
        when profile.activeMatch != null && !_settling) {
      final action = activeMatchAction(
        activeMatchId: profile.activeMatch!.matchId,
        lastMatchId: profile.lastMatchId,
      );
      if (action != ActiveMatchAction.none) {
        _settling = true;
        Future.microtask(
          () => _settleActiveMatch(profile.activeMatch!.matchId),
        );
      }
    }
    return HomeState(
      profile: p.value ?? Profile(nickname: _auth.nickname),
      needsNickname: p.hasValue && p.value == null,
      holiday: ref.watch(holidayProvider).value,
    );
  }

  /// 남은 `activeMatch` 판을 패배(보상 0, 전적 1패)로 저장하고 표시를 지운다. 이미 저장된 판이면
  /// 표시만 지우고 안내는 없다. 실패하면 다음 실행에서 다시 한다.
  Future<void> _settleActiveMatch(String matchId) async {
    try {
      final uid = await _auth.signIn();
      final change = await ref
          .read(profileRepositoryProvider)
          .applyMatch(
            uid,
            matchId,
            ResultViewModel(
              MatchStats(matchId: matchId, result: MatchResult.lose),
              mode: MatchMode.pvp,
              forfeit: true,
            ).applyTo,
          );
      if (change != null) ref.read(forfeitNoticeProvider.notifier).show();
    } catch (e) {
      debugPrint('끝내지 않은 대전 기록 실패: $e');
    } finally {
      _settling = false;
    }
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
      debugPrint('닉네임 저장 실패: $e');
      return connectionErrorText;
    }
  }
}
