import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/settings_repository.dart';
import '../../data/services/auth_service.dart';
import '../../rules/balance.dart';
import '../home/nickname_form.dart';
import '../restart_scope.dart';
import '../style.dart';
import 'settings_view_model.dart';

/// 설정(홈 아래 메뉴 "설정"). 바꾸면 바로 기기에 저장, 게임에는 다음 매치부터.
class SettingsView extends ConsumerWidget {
  const SettingsView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(settingsProvider).value ?? const SettingsState();
    final vm = ref.read(settingsProvider.notifier);
    final email = ref.watch(googleLinkProvider);
    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: panelColor,
        toolbarHeight: 44,
        title: const Text('설정'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          children: [
            Row(
              children: [
                const SizedBox(width: 120, child: Text('시점 감도')),
                Expanded(
                  child: Slider(
                    value: s.sensitivity,
                    min: minSensitivity,
                    max: maxSensitivity,
                    divisions:
                        ((maxSensitivity - minSensitivity) / sensitivityStep)
                            .round(),
                    label: s.sensitivity.toStringAsFixed(1),
                    activeColor: amberColor,
                    onChanged: (v) => unawaited(vm.setSensitivity(v)),
                  ),
                ),
                SizedBox(
                  width: 36,
                  child: Text(s.sensitivity.toStringAsFixed(1)),
                ),
              ],
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('미니맵 회전'),
              subtitle: Text(
                s.minimapRotates ? '내가 보는 쪽이 위' : '고정: 내 진영이 늘 아래',
              ),
              value: s.minimapRotates,
              activeThumbColor: amberColor,
              onChanged: (v) => unawaited(vm.setMinimapRotates(v)),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('효과음'),
              value: s.soundEnabled,
              activeThumbColor: amberColor,
              onChanged: (v) => unawaited(vm.setSoundEnabled(v)),
            ),
            const Divider(),
            for (final (primary, label) in [(true, '주무기'), (false, '보조무기')])
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    SizedBox(width: 120, child: Text('$label 발사')),
                    SegmentedButton<FireMode>(
                      showSelectedIcon: false,
                      segments: const [
                        ButtonSegment(
                          value: FireMode.auto,
                          label: Text('AUTO'),
                        ),
                        ButtonSegment(
                          value: FireMode.manual,
                          label: Text('MANUAL'),
                        ),
                      ],
                      selected: {
                        primary ? s.primaryFireMode : s.secondaryFireMode,
                      },
                      onSelectionChanged: (v) =>
                          unawaited(vm.setFireMode(v.first, primary: primary)),
                    ),
                  ],
                ),
              ),
            const Divider(),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('닉네임 변경'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => unawaited(
                showDialog<void>(
                  context: context,
                  builder: (_) =>
                      const AlertDialog(content: NicknameForm(first: false)),
                ),
              ),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('구글 계정 연결'),
              subtitle: Text(email ?? '연결하면 기기를 바꿔도 골드·무기·전적을 이어 갑니다'),
              trailing: email == null ? const Icon(Icons.chevron_right) : null,
              onTap: email == null
                  ? () => unawaited(_link(context, ref))
                  : null,
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('앱 버전'),
              trailing: Text(ref.watch(appVersionProvider).value ?? ''),
            ),
          ],
        ),
      ),
    );
  }
}

/// 구글 연결. 이미 다른 계정에 붙은 구글이면 확인을 받고 그 계정으로 바꾼다(지금 데이터는 사라짐).
Future<void> _link(BuildContext context, WidgetRef ref) async {
  final vm = ref.read(googleLinkProvider.notifier);
  final messenger = ScaffoldMessenger.of(context);
  try {
    final result = await vm.link();
    if (result != GoogleLink.exists || !context.mounted) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('이미 사용 중인 구글 계정'),
        content: const Text(
          '이 구글 계정에는 저장된 데이터가 있습니다.\n'
          '그 계정으로 바꾸면 지금 기기의 골드·무기·전적은 사라집니다.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('바꾸기'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await vm.switchAccount();
    if (context.mounted) RestartScope.restart(context);
  } catch (_) {
    messenger.showSnackBar(const SnackBar(content: Text('구글 계정을 연결하지 못했습니다')));
  }
}
