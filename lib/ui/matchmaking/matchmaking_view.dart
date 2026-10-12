import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../game/net/match_sync.dart';
import '../../rules/rewards.dart';
import '../match/match_view.dart';
import 'matchmaking_view_model.dart';

/// 빠른 대전 1대1. "봇과 대전"을 누르면 true로 닫힌다(로비가 봇전을 연다).
class MatchmakingView extends ConsumerWidget {
  const MatchmakingView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vm = ref.read(matchmakingProvider.notifier);
    ref.listen(matchmakingProvider, (prev, next) {
      if (prev?.started != true && next.started) {
        unawaited(
          Navigator.of(context).pushReplacement(
            MaterialPageRoute<void>(
              builder: (_) => MatchView(
                mode: MatchMode.pvp,
                match: MatchSync(
                  rooms: vm.rooms,
                  code: next.roomId!,
                  uid: next.uid!,
                  isHost: next.isHost,
                ),
              ),
            ),
          ),
        );
      }
    });
    final s = ref.watch(matchmakingProvider);
    final secs = s.elapsed.inSeconds;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SizedBox(
            width: 320,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (s.error != null)
                  Text(
                    s.error!,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  )
                else if (s.found) ...[
                  const Text(
                    '상대를 찾았습니다!',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 8),
                  Text(s.opponent!, textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  Text(
                    '${s.countdown > 0 ? s.countdown : '시작!'}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 56,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ] else ...[
                  Text(
                    '상대를 찾는 중... ${secs ~/ 60}:${(secs % 60).toString().padLeft(2, '0')}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 20),
                  ),
                  const SizedBox(height: 24),
                  if (s.offerBot) ...[
                    FilledButton(
                      onPressed: () async {
                        await vm.cancel();
                        if (context.mounted) Navigator.of(context).pop(true);
                      },
                      child: const Text('봇과 대전'),
                    ),
                    const SizedBox(height: 12),
                  ],
                ],
                if (!s.found)
                  OutlinedButton(
                    onPressed: () async {
                      await vm.cancel();
                      if (context.mounted) Navigator.of(context).pop();
                    },
                    child: Text(s.error != null ? '돌아가기' : '취소'),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
