import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../rules/balance.dart';
import '../../rules/combat.dart';
import '../../rules/loadout.dart';
import '../../rules/upgrade.dart';
import '../format.dart';
import '../style.dart';
import 'loadout_view_model.dart';

/// 무기 화면(홈 아래 메뉴 "무기"): 계열 탭, 목록, 상세·구매·장착.
class LoadoutView extends ConsumerWidget {
  const LoadoutView({super.key});

  static const _tabs = [
    (WeaponFamily.rifle, '라이플'),
    (WeaponFamily.sniper, '저격'),
    (WeaponFamily.shotgun, '샷건'),
    (WeaponFamily.pistol, '보조'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(loadoutProvider);
    final vm = ref.read(loadoutProvider.notifier);
    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: panelColor,
        toolbarHeight: 44,
        title: Row(
          children: [
            const Text('무기'),
            const SizedBox(width: 24),
            for (final (f, label) in _tabs)
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: ChoiceChip(
                  label: Text(label),
                  selected: s.family == f,
                  onSelected: (_) => vm.showFamily(f),
                ),
              ),
          ],
        ),
        actions: [
          const Icon(Icons.monetization_on, size: 18, color: amberColor),
          const SizedBox(width: 4),
          Text(commas(s.profile.gold)),
          const SizedBox(width: 16),
        ],
      ),
      body: SafeArea(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: 200,
              child: ListView(
                children: [
                  for (final w in s.list) _WeaponTile(w, s, () => vm.select(w)),
                ],
              ),
            ),
            const VerticalDivider(width: 1),
            Expanded(child: _Detail(s, vm)),
          ],
        ),
      ),
    );
  }
}

class _WeaponTile extends StatelessWidget {
  const _WeaponTile(this.w, this.s, this.onTap);

  final WeaponStats w;
  final LoadoutState s;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final owned = s.owns(w);
    return ListTile(
      dense: true,
      selected: s.selected == w,
      selectedTileColor: panelColor,
      onTap: onTap,
      leading: Icon(
        owned ? Icons.gps_fixed : Icons.lock,
        color: owned ? lightColor : lightColor.withValues(alpha: 0.4),
      ),
      title: Text(
        withLevel(w.name, s.levelOf(w)),
        style: TextStyle(
          fontWeight: FontWeight.w800,
          color: owned ? lightColor : lightColor.withValues(alpha: 0.4),
        ),
      ),
      trailing: s.isEquipped(w)
          ? const Text(
              '장착',
              style: TextStyle(color: amberColor, fontWeight: FontWeight.w900),
            )
          : owned
          ? null
          : Text(
              '${commas(weaponPrice)} G',
              style: TextStyle(color: lightColor.withValues(alpha: 0.5)),
            ),
    );
  }
}

class _Detail extends StatelessWidget {
  const _Detail(this.s, this.vm);

  final LoadoutState s;
  final LoadoutViewModel vm;

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

  /// 등급·강화 배율을 넣은 한 발 데미지(소수 한 자리).
  static String damageText(WeaponStats w, int level) =>
      (w.damage * gradeMultiplier(Grade.e, level)).toStringAsFixed(1);

  @override
  Widget build(BuildContext context) {
    final w = s.selected;
    final level = s.levelOf(w);
    final b = statBars(w, weapons);
    final shotgun = w.family == WeaponFamily.shotgun;
    final rows = [
      ('데미지', b.damage, '${shotgun ? '최대 ' : ''}${damageText(w, level)}'),
      ('연사 속도', b.fireRate, '${(1 / w.fireInterval).toStringAsFixed(1)}발/초'),
      ('사거리', b.range, '${w.range.round()}'),
      ('탄창', b.magazine, '${w.magazine}'),
      ('기동성', b.mobility, '×${w.moveSpeed}'),
    ];
    final ttkText = ttk(
      w,
      damageMultiplier: gradeMultiplier(Grade.e, level),
    ).toStringAsFixed(2);
    // 가로 화면 높이에 맞게 두 칸: 왼쪽은 이름·능력치, 오른쪽은 장단점·강화·장착/구매.
    // 장착/구매 버튼은 오른쪽 칸 맨 아래에 붙어서 스크롤 없이 늘 보인다.
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
                    children: [
                      _UpgradeFlash(
                        seq: s.upgradeSeq,
                        result: s.upgradeResult,
                        child: Text(
                          withLevel(w.name, level),
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      const GradeBadge('E'),
                    ],
                  ),
                  Text(
                    'TTK $ttkText초 (체력 100, 전부 명중)',
                    style: const TextStyle(fontSize: 12),
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
                            width: 76,
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
                Text('장점  ${w.pros}'),
                Text('단점  ${w.cons}'),
                if (s.owns(w)) ...[
                  const SizedBox(height: 10),
                  _UpgradePanel(s, level, () => unawaited(_upgrade(context))),
                ],
                const Spacer(),
                s.owns(w)
                    ? FilledButton(
                        onPressed: s.isEquipped(w)
                            ? null
                            : () => unawaited(vm.equip()),
                        child: Text(s.isEquipped(w) ? '장착 중' : '장착'),
                      )
                    : FilledButton(
                        onPressed: s.canAfford && !s.busy
                            ? () => unawaited(_buy(context))
                            : null,
                        child: Text(
                          s.canAfford
                              ? '구매 ${commas(weaponPrice)} G'
                              : '골드 부족 (${commas(weaponPrice)} G)',
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

/// 강화 카드: "+2 → +3", 비용·성공률, 데미지 변화, [강화]. +5면 최대, 골드 부족이면 막힘.
class _UpgradePanel extends StatelessWidget {
  const _UpgradePanel(this.s, this.level, this.onUpgrade);

  final LoadoutState s;
  final int level;
  final VoidCallback onUpgrade;

  @override
  Widget build(BuildContext context) {
    final w = s.selected;
    if (level >= maxUpgradeLevel) {
      return const Text(
        '최대 강화 (+5)',
        style: TextStyle(color: amberColor, fontWeight: FontWeight.w900),
      );
    }
    final cost = upgradeCost(level);
    final enough = s.profile.gold >= cost;
    final chance = (upgradeChance(level) * 100).round();
    final from = _Detail.damageText(w, level);
    final to = _Detail.damageText(w, level + 1);
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      decoration: BoxDecoration(
        color: panelColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '강화 +$level → +${level + 1}',
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
          Text(
            '${commas(cost)} G · 성공률 $chance%',
            style: const TextStyle(fontSize: 12),
          ),
          Text('데미지 $from → $to', style: const TextStyle(fontSize: 12)),
          const SizedBox(height: 6),
          FilledButton.tonal(
            onPressed: enough && !s.busy ? onUpgrade : null,
            child: Text(enough ? '강화' : '골드 부족'),
          ),
        ],
      ),
    );
  }
}

/// 강화 결과 연출(약 1초): 성공이면 이름 뒤가 빛나며 "강화 성공!", 실패면 흔들리며 "강화 실패".
class _UpgradeFlash extends StatefulWidget {
  const _UpgradeFlash({
    required this.seq,
    required this.result,
    required this.child,
  });

  /// 바뀔 때마다 한 번 재생.
  final int seq;
  final UpgradeOutcome? result;
  final Widget child;

  @override
  State<_UpgradeFlash> createState() => _UpgradeFlashState();
}

class _UpgradeFlashState extends State<_UpgradeFlash>
    with SingleTickerProviderStateMixin {
  late final _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );

  @override
  void didUpdateWidget(_UpgradeFlash old) {
    super.didUpdateWidget(old);
    if (widget.seq != old.seq) unawaited(_c.forward(from: 0));
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) {
        final t = _c.value;
        final playing = _c.isAnimating;
        final ok = widget.result == UpgradeOutcome.success;
        final fade = 1 - t;
        final shake = playing && !ok ? sin(t * pi * 10) * 8 * fade : 0.0;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Transform.translate(
              offset: Offset(shake, 0),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  boxShadow: [
                    if (playing && ok)
                      BoxShadow(
                        color: amberColor.withValues(alpha: 0.8 * fade),
                        blurRadius: 24,
                        spreadRadius: 4,
                      ),
                  ],
                ),
                child: child,
              ),
            ),
            if (playing)
              Text(
                ok ? '강화 성공!' : '강화 실패',
                style: TextStyle(
                  color: (ok ? amberColor : const Color(0xFFE0563F)).withValues(
                    alpha: fade,
                  ),
                  fontWeight: FontWeight.w900,
                ),
              ),
          ],
        );
      },
      child: widget.child,
    );
  }
}
