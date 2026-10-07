import 'dart:async';

import 'package:flame_riverpod/flame_riverpod.dart';
import 'package:flutter/material.dart';

import '../../data/models/match_stats.dart';
import '../../game/net/match_sync.dart';
import '../../game/soldier_game.dart';
import '../result/result_view.dart';

/// 게임 화면. [match]가 없으면 오프라인 훈련소.
// ponytail: 뷰모델 없음. 할 일이 나가기뿐이고 그건 MatchSync가 한다. 화면 상태가 늘면 분리.
class MatchView extends StatefulWidget {
  const MatchView({super.key, this.match});

  final MatchSync? match;

  @override
  State<MatchView> createState() => _MatchViewState();
}

class _MatchViewState extends State<MatchView> {
  final _gameKey = GlobalKey<RiverpodAwareGameWidgetState<SoldierGame>>();
  late final _game = SoldierGame(match: widget.match);
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
          MaterialPageRoute<void>(builder: (_) => ResultView(stats: result)),
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
        if (!didPop) unawaited(_exit());
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
              onPressed: () => unawaited(_exit()),
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
