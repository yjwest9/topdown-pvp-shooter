import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/room.dart';
import '../../game/net/match_sync.dart';
import '../../rules/map_select.dart';
import '../../rules/rewards.dart';
import '../../rules/room_teams.dart';
import '../map_chips.dart';
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

  Future<void> _play(MatchSync match, MapInfo map) async {
    // 결과 화면에서 홈으로 가면 이 화면도 닫히므로 미리 잡아 둔다.
    final vm = ref.read(lobbyProvider.notifier);
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            MatchView(match: match, mapInfo: map, mode: MatchMode.custom),
      ),
    );
    vm.backToMenu();
  }

  Future<void> _copy(String code) async {
    await Clipboard.setData(ClipboardData(text: code));
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('방 코드 $code 를 복사했습니다')));
  }

  @override
  Widget build(BuildContext context) {
    final vm = ref.read(lobbyProvider.notifier);
    ref.listen(lobbyProvider, (prev, next) {
      if (prev?.noticeSeq != next.noticeSeq && next.notice != null) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(next.notice!)));
      }
      if (prev?.code == null && next.code != null) _codeInput.clear();
      if (prev?.started != true && next.started) {
        unawaited(
          _play(
            MatchSync(
              rooms: vm.rooms,
              code: next.code!,
              uid: next.uid!,
              isHost: next.isHost,
              teamSize: next.teamSize,
              allyIndex: next.allyIndex,
            ),
            mapById(next.map),
          ),
        );
      }
    });
    final s = ref.watch(lobbyProvider);

    // 뒤로 가면 대기실도 나간다.
    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) unawaited(vm.leaveRoom());
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('방 만들기 · 코드 입장')),
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: s.code == null ? _menu(s, vm) : _waitingRoom(s, vm),
            ),
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
          Wrap(
            spacing: 8,
            children: [
              for (final (n, label) in [(1, '1대1'), (2, '2대2')])
                ChoiceChip(
                  label: Text(label),
                  selected: s.teamSize == n,
                  onSelected: (_) => vm.selectTeamSize(n),
                ),
            ],
          ),
          const SizedBox(height: 8),
          MapChips(
            selected: s.map,
            onSelected: vm.selectMap,
            lockedTo: s.teamSize == 2 ? 'outpost' : null,
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
    final start = s.isHost
        ? FilledButton(
            onPressed: s.canStart ? () => unawaited(vm.start()) : null,
            child: Text(s.canStart ? '시작' : '상대를 기다리는 중'),
          )
        : const Text('방장이 시작하기를 기다리는 중');
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('방 코드'),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              s.code!,
              style: const TextStyle(
                fontSize: 56,
                fontWeight: FontWeight.w900,
                letterSpacing: 8,
              ),
            ),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              onPressed: () => unawaited(_copy(s.code!)),
              icon: const Icon(Icons.copy, size: 18),
              label: const Text('복사'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('맵 ${mapById(s.map).label}'),
            Text(' · ${s.teamSize}대${s.teamSize}'),
          ],
        ),
        const SizedBox(height: 8),
        if (s.incoming case final req?) _incoming(req, vm),
        if (s.outgoing case final target?)
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            children: [
              Text('${target.name}님에게 자리 바꾸기 요청 중…'),
              TextButton(
                onPressed: () => unawaited(vm.cancelSwap()),
                child: const Text('취소'),
              ),
            ],
          ),
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _team(teamAId, s, vm),
            const SizedBox(width: 24),
            _team(teamBId, s, vm),
          ],
        ),
        const SizedBox(height: 12),
        start,
        const SizedBox(height: 8),
        TextButton(
          onPressed: () => unawaited(vm.leaveRoom()),
          child: const Text('나가기'),
        ),
      ],
    );
  }

  /// 받은 자리 바꾸기 요청: 수락 / 거절.
  Widget _incoming(RoomPlayer req, LobbyViewModel vm) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          children: [
            Text('${req.name}님이 자리 바꾸기를 요청했습니다'),
            FilledButton(
              onPressed: () => unawaited(vm.acceptSwap()),
              child: const Text('수락'),
            ),
            OutlinedButton(
              onPressed: () => unawaited(vm.declineSwap()),
              child: const Text('거절'),
            ),
          ],
        ),
      ),
    );
  }

  /// 한 팀 칸: teamSize 자리(빈자리 표시), 상대 팀이면 "이 팀으로"와 사람 옆 "자리 바꾸기".
  Widget _team(String team, LobbyState s, LobbyViewModel vm) {
    final members = s.teamPlayers(team);
    final mine = team == s.myTeam;
    final slots = members.length > s.teamSize ? members.length : s.teamSize;
    return SizedBox(
      width: 200,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$team팀${mine ? ' (내 팀)' : ''}',
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
          for (var i = 0; i < slots; i++)
            if (i < members.length)
              Row(
                children: [
                  Expanded(
                    child: Text(
                      members[i].uid == s.uid
                          ? '${members[i].name} (나)'
                          : members[i].name,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (!mine)
                    TextButton(
                      onPressed: s.swapBlock(members[i].uid) == SwapBlock.ok
                          ? () => unawaited(vm.requestSwap(members[i].uid))
                          : null,
                      child: const Text('자리 바꾸기'),
                    ),
                ],
              )
            else
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  '빈자리',
                  style: TextStyle(
                    color: Theme.of(context).disabledColor,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
          if (!mine && s.canMove)
            OutlinedButton(
              onPressed: () => unawaited(vm.moveToOtherTeam()),
              child: const Text('이 팀으로'),
            ),
        ],
      ),
    );
  }
}
