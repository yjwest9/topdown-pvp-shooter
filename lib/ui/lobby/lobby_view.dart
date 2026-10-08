import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../game/net/match_sync.dart';
import '../../rules/balance.dart';
import '../match/match_view.dart';
import 'lobby_view_model.dart';

class LobbyView extends ConsumerStatefulWidget {
  const LobbyView({super.key});

  @override
  ConsumerState<LobbyView> createState() => _LobbyViewState();
}

class _LobbyViewState extends ConsumerState<LobbyView> {
  final _codeInput = TextEditingController();

  @override
  void dispose() {
    _codeInput.dispose();
    super.dispose();
  }

  Future<void> _play(MatchSync? match) async {
    await Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => MatchView(match: match)));
    if (match != null) ref.read(lobbyProvider.notifier).backToMenu();
  }

  @override
  Widget build(BuildContext context) {
    final vm = ref.read(lobbyProvider.notifier);
    ref.listen(lobbyProvider, (prev, next) {
      if (prev?.started != true && next.started) {
        unawaited(
          _play(
            MatchSync(
              rooms: vm.rooms,
              code: next.code!,
              uid: next.uid!,
              isHost: next.isHost,
            ),
          ),
        );
      }
    });
    final s = ref.watch(lobbyProvider);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: s.code == null ? _menu(s, vm) : _waitingRoom(s, vm),
          ),
        ),
      ),
    );
  }

  Widget _menu(LobbyState s, LobbyViewModel vm) {
    return SizedBox(
      width: 320,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'TOP SOLDIER',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900),
          ),
          if (ref.watch(holidayProvider).value case final h?) ...[
            const SizedBox(height: 8),
            Text(
              '오늘은 ${h.name}! 매치 보상 $holidayRewardMultiplier배 이벤트',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFFE8B33A),
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          const SizedBox(height: 24),
          FilledButton(
            onPressed: () => unawaited(_play(null)),
            child: const Text('훈련소'),
          ),
          const SizedBox(height: 12),
          FilledButton.tonal(
            onPressed: s.busy ? null : () => unawaited(vm.createRoom()),
            child: const Text('방 만들기'),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _codeInput,
                  keyboardType: TextInputType.number,
                  maxLength: 4,
                  decoration: const InputDecoration(
                    labelText: '방 코드',
                    counterText: '',
                  ),
                ),
              ),
              const SizedBox(width: 12),
              OutlinedButton(
                onPressed: s.busy
                    ? null
                    : () => unawaited(vm.joinRoom(_codeInput.text.trim())),
                child: const Text('코드로 입장'),
              ),
            ],
          ),
          if (s.error != null) ...[
            const SizedBox(height: 12),
            Text(
              s.error!,
              textAlign: TextAlign.center,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
        ],
      ),
    );
  }

  Widget _waitingRoom(LobbyState s, LobbyViewModel vm) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('방 코드'),
        Text(
          s.code!,
          style: const TextStyle(
            fontSize: 56,
            fontWeight: FontWeight.w900,
            letterSpacing: 8,
          ),
        ),
        const SizedBox(height: 16),
        for (final p in s.players)
          Text(p.uid == s.uid ? '${p.name} (나)' : p.name),
        const SizedBox(height: 16),
        if (s.isHost)
          FilledButton(
            onPressed: s.canStart ? () => unawaited(vm.start()) : null,
            child: Text(s.canStart ? '시작' : '상대를 기다리는 중'),
          )
        else
          const Text('방장이 시작하기를 기다리는 중'),
        const SizedBox(height: 8),
        TextButton(
          onPressed: () => unawaited(vm.leaveRoom()),
          child: const Text('나가기'),
        ),
      ],
    );
  }
}
