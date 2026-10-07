import 'dart:async';

import 'package:flame_riverpod/flame_riverpod.dart';
import 'package:flutter/material.dart';

import '../../game/net/match_sync.dart';
import '../../game/soldier_game.dart';

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
    widget.match?.onOpponentLeft = () {
      setState(() => _message = '상대가 나갔습니다');
      Future.delayed(const Duration(seconds: 2), _exit);
    };
  }

  Future<void> _exit() async {
    if (_exiting) return;
    _exiting = true;
    await widget.match?.leave();
    if (mounted) Navigator.of(context).pop();
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
          // 왼쪽 위 나침반·자세 글자 아래. 위 가운데는 상대가 자주 보이는 자리라 피한다.
          Positioned(
            left: 4,
            top: 100,
            child: SafeArea(
              child: TextButton(
                onPressed: () => unawaited(_exit()),
                child: const Text(
                  '나가기',
                  style: TextStyle(color: Color(0xFFE3E6D8)),
                ),
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
