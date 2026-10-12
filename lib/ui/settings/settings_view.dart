import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/settings_repository.dart';
import '../../rules/balance.dart';
import '../home/nickname_form.dart';
import '../style.dart';
import 'settings_view_model.dart';

/// 설정(홈 아래 메뉴 "설정"). 바꾸면 바로 기기에 저장, 게임에는 다음 매치부터.
class SettingsView extends ConsumerWidget {
  const SettingsView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(settingsProvider).value ?? const SettingsState();
    final vm = ref.read(settingsProvider.notifier);
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
              title: const Text('앱 버전'),
              trailing: Text(ref.watch(appVersionProvider).value ?? ''),
            ),
          ],
        ),
      ),
    );
  }
}
