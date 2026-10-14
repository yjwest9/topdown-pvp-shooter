import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// AdMob 보상형 광고(decisions 10장). 안드로이드만, 웹·그 밖은 [supported]가 false.
class AdService {
  /// Google 공식 테스트 보상형 광고 단위(공개값). 실제 ID는 출시 때
  /// `--dart-define=ADMOB_REWARDED_ID=...`로 넣는다(앱 ID는 AndroidManifest).
  static const _rewardedId = 'ca-app-pub-3940256099942544/5224354917';

  bool get supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  Future<InitializationStatus>? _init;
  RewardedAd? _ad;

  Future<bool>? _loading;

  /// 광고 하나를 미리 불러 둔다. 이미 있으면 그대로 true, 실패하면 false.
  /// 불러오는 중에 또 부르면(홈 → 바로 상점) 같은 요청을 기다린다.
  Future<bool> load() async {
    if (!supported) return false;
    if (_ad != null) return true;
    return _loading ??= _load().whenComplete(() => _loading = null);
  }

  Future<bool> _load() async {
    final done = Completer<bool>();
    try {
      await (_init ??= MobileAds.instance.initialize());
      await RewardedAd.load(
        adUnitId: _rewardedId,
        request: const AdRequest(),
        rewardedAdLoadCallback: RewardedAdLoadCallback(
          onAdLoaded: (ad) {
            _ad = ad;
            done.complete(true);
          },
          onAdFailedToLoad: (_) => done.complete(false),
        ),
      );
    } on Object {
      if (!done.isCompleted) done.complete(false);
    }
    return done.future;
  }

  /// 불러 둔 광고를 보여 주고 닫힐 때까지 기다린다. 보상 콜백(onUserEarnedReward)이
  /// 왔을 때만 true. 중간에 닫았거나 못 보여 줬으면 false. 보여 준 광고는 버린다.
  Future<bool> show() async {
    final ad = _ad;
    if (ad == null) return false;
    _ad = null;
    var earned = false;
    final closed = Completer<void>();
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        unawaited(ad.dispose());
        closed.complete();
      },
      onAdFailedToShowFullScreenContent: (ad, _) {
        unawaited(ad.dispose());
        closed.complete();
      },
    );
    await ad.show(onUserEarnedReward: (_, _) => earned = true);
    await closed.future;
    return earned;
  }
}
