import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/profile.dart';
import '../../data/repositories/ad_repository.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/profile_repository.dart';
import '../../data/repositories/room_repository.dart';
import '../../rules/balance.dart';
import '../../rules/shop.dart';

/// 광고 버튼 상태. [unsupported]는 웹("앱에서만 가능").
enum AdStatus { unsupported, loading, ready, failed }

/// 광고를 본 결과.
enum AdReward { none, paid, failed, offline }

class ShopState {
  const ShopState({
    required this.profile,
    required this.ad,
    this.offsetMs = 0,
    this.busy = false,
  });

  final Profile profile;
  final AdStatus ad;

  /// 서버 시간 − 기기 시간(`.info/serverTimeOffset`).
  final int offsetMs;
  final bool busy;

  /// [nowMs](기기 시간) 기준 광고를 다시 보기까지 남은 시간.
  Duration cooldownLeft(int nowMs) =>
      adCooldownLeft(profile.lastAdAt, nowMs + offsetMs);

  bool get canExchange =>
      exchangeGold(gold: profile.gold, diamond: profile.diamond) != null;

  ShopState copyWith({
    Profile? profile,
    AdStatus? ad,
    int? offsetMs,
    bool? busy,
  }) => ShopState(
    profile: profile ?? this.profile,
    ad: ad ?? this.ad,
    offsetMs: offsetMs ?? this.offsetMs,
    busy: busy ?? this.busy,
  );
}

final shopProvider = NotifierProvider.autoDispose<ShopViewModel, ShopState>(
  ShopViewModel.new,
);

class ShopViewModel extends Notifier<ShopState> {
  AuthRepository get _auth => ref.read(authRepositoryProvider);
  ProfileRepository get _repo => ref.read(profileRepositoryProvider);
  AdRepository get _ads => ref.read(adRepositoryProvider);

  @override
  ShopState build() {
    // watch로 다시 만들면 아래 구독이 끊기므로 listen으로 프로필만 바꾼다.
    ref.listen(profileProvider, (_, next) {
      final p = next.value;
      if (p != null) state = state.copyWith(profile: p);
    });
    final sub = ref
        .read(roomRepositoryProvider)
        .serverTimeOffset()
        .listen((o) => state = state.copyWith(offsetMs: o));
    ref.onDispose(sub.cancel);
    final supported = _ads.supported;
    if (supported) unawaited(Future.microtask(loadAd));
    return ShopState(
      profile:
          ref.read(profileProvider).value ?? Profile(nickname: _auth.nickname),
      ad: supported ? AdStatus.loading : AdStatus.unsupported,
    );
  }

  /// 광고를 불러 둔다(처음, 다시 시도, 보고 난 뒤).
  Future<void> loadAd() async {
    state = state.copyWith(ad: AdStatus.loading);
    final ok = await _ads.load();
    if (ref.mounted) {
      state = state.copyWith(ad: ok ? AdStatus.ready : AdStatus.failed);
    }
  }

  /// 광고를 보여 주고, 끝까지 봤으면(보상 콜백) 골드를 받는다.
  /// 닫기만 했으면 [AdReward.none]. 광고 전에 DB에 연결이 안 돼 있으면 광고를 보여 주지 않고
  /// [AdReward.offline]. 서버에 쓰지 못했거나 [requestTimeout] 안에 안 끝나면 [AdReward.failed]
  /// (쿨타임도 시작되지 않는다).
  Future<AdReward> watchAd() async {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (state.ad != AdStatus.ready ||
        state.busy ||
        state.cooldownLeft(now) > Duration.zero) {
      return AdReward.none;
    }
    final connection = ref.read(roomRepositoryProvider).connection;
    state = state.copyWith(busy: true);
    var reload = true;
    try {
      // 광고를 보고도 보상을 못 받는 일이 없게, 연결이 없으면 광고 전에 알린다.
      if (!await connection.ensureConnected()) {
        reload = false;
        return AdReward.offline;
      }
      if (!await _ads.show()) return AdReward.none;
      try {
        // 광고를 보는 동안 끊겼을 수 있다.
        if (!await connection.ensureConnected()) return AdReward.failed;
        await _repo
            .rewardAd(await _auth.signIn(), adRewardGold)
            .timeout(requestTimeout);
        return AdReward.paid;
      } catch (e) {
        debugPrint('광고 보상 저장 실패: $e');
        return AdReward.failed;
      }
    } finally {
      if (ref.mounted) {
        state = state.copyWith(busy: false);
        if (reload) unawaited(loadAd());
      }
    }
  }

  /// 환전 한 번. 골드가 모자라면 false.
  Future<bool> exchange() async {
    if (!state.canExchange || state.busy) return false;
    state = state.copyWith(busy: true);
    try {
      return await _repo.exchange(
        await _auth.signIn(),
        (gold, diamond) => exchangeGold(gold: gold, diamond: diamond),
      );
    } finally {
      if (ref.mounted) state = state.copyWith(busy: false);
    }
  }
}
