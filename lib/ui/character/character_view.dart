import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../rules/balance.dart';
import '../../rules/character.dart';
import '../../rules/upgrade.dart';
import '../character_figure.dart';
import '../format.dart';
import '../loadout/loadout_view_model.dart';
import '../style.dart';
import '../upgrade_widgets.dart';
import 'character_view_model.dart';

const _diamondColor = Color(0xFF7FD4F0);

String _pct(double v) => '${(v * 100).round()}%';

/// 강화로 오르는 능력치: (이름, 값 글자, 1단계마다 글자).
(String, String Function(CharacterStats), String) _growth(CharacterStats c) =>
    c.hpPerLevel > 0
    ? ('체력', (x) => '${x.hp}', '+${c.hpPerLevel}')
    : c.accuracyPerLevel > 0
    ? ('명중', (x) => _pct(x.accuracy), '+${_pct(c.accuracyPerLevel)}p')
    : c.evasionPerLevel > 0
    ? ('회피', (x) => _pct(x.evasion), '+${_pct(c.evasionPerLevel)}p')
    : ('크리티컬', (x) => _pct(x.crit), '+${_pct(c.critPerLevel)}p');

/// 캐릭터 화면(홈 아래 메뉴 "캐릭터", decisions 8장): 위쪽 탭으로 고르고, 왼쪽에 서 있는
/// 모습, 가운데 능력치, 오른쪽 구매·장착·강화.
class CharacterView extends ConsumerWidget {
  const CharacterView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(characterProvider);
    final vm = ref.read(characterProvider.notifier);
    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: panelColor,
        toolbarHeight: 44,
        title: const Text('캐릭터'),
        actions: [
          const Icon(Icons.monetization_on, size: 18, color: amberColor),
          const SizedBox(width: 4),
          Text(commas(s.profile.gold)),
          const SizedBox(width: 16),
          const Icon(Icons.diamond, size: 18, color: _diamondColor),
          const SizedBox(width: 4),
          Text(commas(s.profile.diamond)),
          const SizedBox(width: 16),
        ],
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 캐릭터 고르기 탭. 장착 = 체크, 미보유 = 자물쇠.
            SizedBox(
              height: 44,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(12, 6, 12, 2),
                children: [
                  for (final c in characters)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        showCheckmark: false,
                        avatar: s.isEquipped(c)
                            ? const Icon(
                                Icons.check,
                                size: 16,
                                color: amberColor,
                              )
                            : s.owns(c)
                            ? null
                            : const Icon(Icons.lock, size: 14),
                        label: Text(withLevel(c.name, s.levelOf(c))),
                        selected: s.selected == c,
                        onSelected: (_) => vm.select(c),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 정면에서 서 있는 큰 그림 + 장착 주무기(decisions 8장).
                  SizedBox(
                    width: 190,
                    child: LayoutBuilder(
                      builder: (context, box) => Center(
                        child: CharacterFigure(
                          s.selected.id,
                          weaponId: equippedWeapons(s.profile).primary.id,
                          height: min(box.maxHeight - 16, box.maxWidth * 1.6),
                          dim: !s.owns(s.selected),
                        ),
                      ),
                    ),
                  ),
                  const VerticalDivider(width: 1),
                  Expanded(child: _Detail(s, vm)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Detail extends StatelessWidget {
  const _Detail(this.s, this.vm);

  final CharacterState s;
  final CharacterViewModel vm;

  Future<void> _buy(BuildContext context) async {
    final ok = await vm.buy();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok ? '${s.selected.name}을(를) 샀습니다' : '구매하지 못했습니다'),
      ),
    );
  }

  Future<void> _upgrade(BuildContext context) async {
    final r = await vm.upgrade();
    if (r == null && context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('강화하지 못했습니다. 다시 시도해 주세요')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final base = s.selected;
    final level = s.levelOf(base);
    final c = upgradedCharacter(base, level);
    final owned = s.owns(base);
    final (growName, growValue, perLevel) = _growth(base);
    // 막대는 +5까지 갔을 때 가장 큰 값 기준.
    double top(double Function(CharacterStats) f) =>
        [for (final x in characters) f(upgradedCharacter(x, maxUpgradeLevel))]
            .reduce((a, b) => a > b ? a : b);
    double bar(double v, double max) => max <= 0 ? 0 : v / max;
    final rows = [
      ('체력', bar(c.hp.toDouble(), top((x) => x.hp.toDouble())), '${c.hp}'),
      ('명중', bar(c.accuracy, top((x) => x.accuracy)), _pct(c.accuracy)),
      ('회피', bar(c.evasion, top((x) => x.evasion)), _pct(c.evasion)),
      ('크리티컬', bar(c.crit, top((x) => x.crit)), _pct(c.crit)),
      ('이동', bar(c.moveSpeed, top((x) => x.moveSpeed)), '×${c.moveSpeed}'),
    ];
    // 무기 화면과 같은 두 칸: 왼쪽 이름·능력치, 오른쪽 강화·장착/구매(버튼은 맨 아래).
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 16, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      UpgradeFlash(
                        seq: s.upgradeSeq,
                        result: s.upgradeResult,
                        child: Text(
                          withLevel(base.name, level),
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  for (final (label, ratio, value) in rows)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Row(
                        children: [
                          SizedBox(width: 64, child: Text(label)),
                          Expanded(
                            child: LinearProgressIndicator(
                              value: ratio,
                              minHeight: 8,
                              color: amberColor,
                              backgroundColor: panelColor,
                            ),
                          ),
                          SizedBox(
                            width: 60,
                            child: Text(value, textAlign: TextAlign.right),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 16),
          SizedBox(
            width: 220,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('강화 1단계마다 $growName $perLevel'),
                if (owned) ...[
                  const SizedBox(height: 10),
                  UpgradePanel(
                    level: level,
                    gold: s.profile.gold,
                    busy: s.busy,
                    change: level >= maxUpgradeLevel
                        ? ''
                        : '$growName ${growValue(c)} → '
                              '${growValue(upgradedCharacter(base, level + 1))}',
                    onUpgrade: () => unawaited(_upgrade(context)),
                  ),
                ],
                const Spacer(),
                owned
                    ? FilledButton(
                        onPressed: s.isEquipped(base)
                            ? null
                            : () => unawaited(vm.equip()),
                        child: Text(s.isEquipped(base) ? '장착 중' : '장착'),
                      )
                    : FilledButton(
                        onPressed: s.canAfford && !s.busy
                            ? () => unawaited(_buy(context))
                            : null,
                        child: Text(
                          s.canAfford
                              ? '구매 $characterPrice 다이아'
                              : '다이아 부족 ($characterPrice 다이아)',
                        ),
                      ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
