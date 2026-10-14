import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/ad_service.dart';

final adRepositoryProvider = Provider((ref) => AdRepository(AdService()));

/// 보상형 광고. 상점에서만 쓴다(매치 중엔 불러오지도 않는다, decisions 10장).
class AdRepository {
  AdRepository(this._ads);

  final AdService _ads;

  /// false면 웹 등 광고를 못 보여 주는 곳("앱에서만 가능").
  bool get supported => _ads.supported;

  /// 광고를 미리 불러 둔다. 실패하면 false.
  Future<bool> load() => _ads.load();

  /// 끝까지 봐서 보상을 받을 자격이 생겼으면 true.
  Future<bool> show() => _ads.show();
}
