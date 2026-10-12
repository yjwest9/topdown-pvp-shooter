import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../game/net/match_sync.dart';
import '../../rules/balance.dart';
import '../match/match_view.dart';
import '../matchmaking/matchmaking_view.dart';
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

  Future<void> _play(MatchSync? match, {BotDifficulty? bot}) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => MatchView(match: match, bot: bot),
      ),
    );
    if (match != null) ref.read(lobbyProvider.notifier).backToMenu();
  }

  Future<void> _playBot(BotDifficulty bot) async {
    final room = await ref.read(lobbyProvider.notifier).botRoom();
    if (!mounted) return;
    await _play(
      MatchSync(rooms: room.rooms, code: room.code, uid: 'me', isHost: true),
      bot: bot,
    );
  }

  /// 빠른 대전. 30초 넘게 못 찾아 "봇과 대전"을 누르면 보통 봇전으로.
  Future<void> _quickMatch() async {
    final bot = await Navigator.of(context)
        .push<bool>(MaterialPageRoute(builder: (_) => const MatchmakingView()));
    if (bot == true && mounted) await _playBot(BotDifficulty.normal);
  }

  @override
  Widget build(BuildContext context) {
    final vm = ref.read(lobbyProvider.notifier);
    ref.listen(lobbyProvider, (prev, next) {
      if (prev?.code == null && next.code != null) _codeInput.clear();
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
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 20),
              textStyle: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
            onPressed: s.busy ? null : () => unawaited(_quickMatch()),
            child: const Text('빠른 대전 1대1'),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: () => unawaited(_play(null)),
            child: const Text('훈련소'),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Text('봇전'),
              const SizedBox(width: 12),
              for (final (bot, label) in [
                (BotDifficulty.easy, '쉬움'),
                (BotDifficulty.normal, '보통'),
                (BotDifficulty.hard, '어려움'),
              ]) ...[
                Expanded(
                  child: FilledButton.tonal(
                    onPressed: () => unawaited(_playBot(bot)),
                    child: Text(label),
                  ),
                ),
                if (bot != BotDifficulty.hard) const SizedBox(width: 8),
              ],
            ],
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
