import 'dart:async';

import 'package:flame_riverpod/flame_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/match_stats.dart';
import '../../data/repositories/profile_repository.dart';
import '../../game/net/match_sync.dart';
import '../../game/soldier_game.dart';
import '../../rules/balance.dart';
import '../../rules/match.dart';
import '../../rules/rewards.dart';
import '../loadout/loadout_view_model.dart';
import '../result/result_view.dart';
import '../result/result_view_model.dart';
import '../settings/settings_view_model.dart';

/// 게임 화면. [match]가 없으면 오프라인 훈련소.
// ponytail: 뷰모델 없음. 할 일이 나가기뿐이고 그건 MatchSync가 한다. 화면 상태가 늘면 분리.
class MatchView extends ConsumerStatefulWidget {
  const MatchView({
    super.key,
    this.match,
    this.bot,
    this.mode = MatchMode.training,
  });

  final MatchSync? match;

  /// 봇전 난이도. [match]는 메모리 DB 방.
  final BotDifficulty? bot;

  /// 보상·나가기 규칙(빠른 대전만 중간에 나가면 패배).
  final MatchMode mode;

  @override
  ConsumerState<MatchView> createState() => _MatchViewState();
}

class _MatchViewState extends ConsumerState<MatchView> {
  final _gameKey = GlobalKey<RiverpodAwareGameWidgetState<SoldierGame>>();

  /// 감도·발사 방식·미니맵은 설정(홈에서 미리 읽어 둠), 무기는 로드아웃.
  /// 못 읽었으면(오프라인 등) 기본값. 게임 중에 설정을 바꿔도 다음 매치부터.
  late final _game = () {
    final settings = ref.read(settingsProvider).value ?? const SettingsState();
    final loadout = equippedWeapons(ref.read(profileProvider).value);
    return SoldierGame(
      match: widget.match,
      bot: widget.bot,
      sensitivity: settings.sensitivity,
      primaryFireMode: settings.primaryFireMode,
      secondaryFireMode: settings.secondaryFireMode,
      minimapRotates: settings.minimapRotates,
      primary: loadout.primary,
      secondary: loadout.secondary,
      onMinimapRotatesChanged: (rotates) => unawaited(
        ref.read(settingsProvider.notifier).setMinimapRotates(rotates),
      ),
    );
  }();
  String? _message;
  bool _exiting = false;

  @override
  void initState() {
    super.initState();
    widget.match?.onMatchEnd = (stats, {required opponentLeft}) async {
      if (opponentLeft) {
        setState(() => _message = '상대가 나갔습니다');
        await Future<void>.delayed(const Duration(seconds: 2));
      }
      await _exit(result: stats);
    };
  }

  /// 나가기 버튼·뒤로 가기. 빠른 대전이면 확인 후 패배로 기록하고 나간다.
  Future<void> _leave() async {
    final match = widget.match;
    if (match != null && widget.mode == MatchMode.pvp) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          content: const Text('지금 나가면 패배로 기록됩니다.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('계속하기'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('나가기'),
            ),
          ],
        ),
      );
      if (ok != true || !mounted || _exiting) return;
      unawaited(
        saveMatchResult(
          ref,
          ResultViewModel(match.statsFor(MatchResult.lose), forfeit: true),
        ),
      );
    }
    await _exit();
  }

  /// 방을 나간다. [result]가 있으면(매치 끝) 결과 화면으로, 없으면(중간에 나감) 로비로.
  Future<void> _exit({MatchStats? result}) async {
    if (_exiting) return;
    _exiting = true;
    await widget.match?.leave();
    if (!mounted) return;
    final nav = Navigator.of(context);
    if (result == null) {
      nav.pop();
    } else {
      unawaited(
        nav.pushReplacement(
          MaterialPageRoute<void>(
            builder: (_) => ResultView(stats: result, mode: widget.mode),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // 뒤로 가기도 나가기 버튼과 같이 방을 나간다.
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(_leave());
      },
      child: _body(),
    );
  }

  Widget _body() {
    return Scaffold(
      body: Stack(
        children: [
          RiverpodAwareGameWidget<SoldierGame>(key: _gameKey, game: _game),
          // 나침반 오른쪽. Flame HUD처럼 화면 모서리 기준이라 SafeArea를 쓰지 않는다
          // (SafeArea가 카메라 구멍만큼 밀어서 폰에서 엉뚱한 자리에 보였다).
          Positioned(
            left: 76,
            top: 4,
            child: TextButton(
              onPressed: () => unawaited(_leave()),
              child: const Text(
                '나가기',
                style: TextStyle(color: Color(0xFFE3E6D8)),
              ),
            ),
          ),
          if (_message != null)
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 28,
                  vertical: 16,
                ),
                color: const Color(0xCC000000),
                child: Text(
                  _message!,
                  style: const TextStyle(
                    color: Color(0xFFE3E6D8),
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
