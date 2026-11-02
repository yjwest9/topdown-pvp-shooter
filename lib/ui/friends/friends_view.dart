import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../rules/balance.dart';
import '../../rules/friends.dart';
import '../style.dart';
import 'friends_view_model.dart';

/// 친구(홈 아래 메뉴 "친구", decisions 18장).
class FriendsView extends ConsumerStatefulWidget {
  const FriendsView({super.key});

  @override
  ConsumerState<FriendsView> createState() => _FriendsViewState();
}

class _FriendsViewState extends ConsumerState<FriendsView> {
  final _code = TextEditingController();

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  FriendsViewModel get _vm => ref.read(friendsProvider.notifier);

  void _toast(String text, {SnackBarAction? action}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text), action: action));
  }

  Future<void> _do(Future<String?> action) async {
    final error = await action;
    if (error != null) _toast(error);
  }

  Future<void> _send() async {
    final r = await _vm.send(_code.text);
    if (r.acceptFrom == null && r.message == '요청을 보냈습니다') _code.clear();
    _toast(
      r.message,
      action: r.acceptFrom == null
          ? null
          : SnackBarAction(
              label: '수락',
              onPressed: () => unawaited(_do(_vm.accept(r.acceptFrom!))),
            ),
    );
  }

  Future<void> _confirmRemove(String uid, String name) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('친구 삭제'),
        content: Text('$name 님을 친구에서 삭제할까요? 상대 목록에서도 사라집니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
    if (ok == true) await _do(_vm.remove(uid));
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(friendsProvider);
    Widget header(String text) => Padding(
      padding: const EdgeInsets.only(top: 14, bottom: 4),
      child: Text(
        text,
        style: const TextStyle(color: amberColor, fontWeight: FontWeight.w900),
      ),
    );
    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: panelColor,
        toolbarHeight: 44,
        title: const Text('친구'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          children: [
            if (s.anonymous)
              const Text(
                '구글 계정을 연결하면 앱을 지워도 친구가 유지됩니다.',
                style: TextStyle(color: Colors.white70),
              ),
            Row(
              children: [
                const Text('내 친구 코드  '),
                SelectableText(
                  s.code ?? '…',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1,
                  ),
                ),
                IconButton(
                  tooltip: '복사',
                  icon: const Icon(Icons.copy, size: 18),
                  onPressed: s.code == null
                      ? null
                      : () async {
                          await Clipboard.setData(ClipboardData(text: s.code!));
                          _toast('복사했습니다');
                        },
                ),
              ],
            ),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _code,
                    decoration: const InputDecoration(
                      hintText: '친구 코드 입력 (TS-ABC234)',
                      isDense: true,
                    ),
                    textCapitalization: TextCapitalization.characters,
                    onSubmitted: (_) => unawaited(_send()),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: amberColor,
                    foregroundColor: bgColor,
                  ),
                  onPressed: () => unawaited(_send()),
                  child: const Text('요청 보내기'),
                ),
              ],
            ),
            if (s.received.isNotEmpty) ...[
              header('받은 요청 (${s.received.length})'),
              for (final r in s.received)
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(r.name),
                  trailing: Wrap(
                    spacing: 6,
                    children: [
                      FilledButton(
                        onPressed: () => unawaited(_do(_vm.accept(r.uid))),
                        child: const Text('수락'),
                      ),
                      OutlinedButton(
                        onPressed: () => unawaited(_do(_vm.reject(r.uid))),
                        child: const Text('거절'),
                      ),
                    ],
                  ),
                ),
            ],
            if (s.sent.isNotEmpty) ...[
              header('보낸 요청 (${s.sent.length})'),
              for (final r in s.sent)
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(r.name),
                  subtitle: const Text('수락을 기다리는 중'),
                  trailing: OutlinedButton(
                    onPressed: () => unawaited(_do(_vm.cancel(r.uid))),
                    child: const Text('취소'),
                  ),
                ),
            ],
            header('친구 (${s.friends.length}/$friendMax)'),
            if (s.friends.isEmpty)
              const Text(
                '아직 친구가 없습니다. 친구 코드를 주고받아 보세요.',
                style: TextStyle(color: Colors.white70),
              ),
            for (final uid in s.friends)
              _FriendTile(uid, onRemove: _confirmRemove),
          ],
        ),
      ),
    );
  }
}

class _FriendTile extends ConsumerWidget {
  const _FriendTile(this.uid, {required this.onRemove});

  final String uid;
  final Future<void> Function(String uid, String name) onRemove;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final info = ref.watch(friendInfoProvider(uid)).value;
    final name = info?.nickname ?? '';
    final online = info?.online ?? false;
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      onLongPress: () => unawaited(onRemove(uid, name)),
      leading: Icon(
        Icons.circle,
        size: 12,
        color: online ? Colors.greenAccent : Colors.white24,
      ),
      title: Text(info == null ? '…' : '$name  Lv.${info.level}'),
      subtitle: Text(
        online
            ? '접속 중'
            : (info?.lastSeen ?? 0) == 0
            ? '오프라인'
            : lastSeenText(
                DateTime.now().millisecondsSinceEpoch,
                info!.lastSeen,
              ),
      ),
      trailing: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          // 3단계(초대 푸시) 자리.
          const OutlinedButton(onPressed: null, child: Text('초대 (준비 중)')),
          IconButton(
            tooltip: '삭제',
            icon: const Icon(Icons.more_vert, size: 18),
            onPressed: () => unawaited(onRemove(uid, name)),
          ),
        ],
      ),
    );
  }
}
