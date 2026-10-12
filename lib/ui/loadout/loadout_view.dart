import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../rules/balance.dart';
import '../../rules/combat.dart';
import '../../rules/loadout.dart';
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
              width: 240,
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
        w.name,
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

  @override
  Widget build(BuildContext context) {
    final w = s.selected;
    final b = statBars(w, weapons);
    final shotgun = w.family == WeaponFamily.shotgun;
    final rows = [
      ('데미지', b.damage, '${shotgun ? '최대 ' : ''}${w.damage.round()}'),
      ('연사 속도', b.fireRate, '${(1 / w.fireInterval).toStringAsFixed(1)}발/초'),
      ('사거리', b.range, '${w.range.round()}'),
      ('탄창', b.magazine, '${w.magazine}'),
      ('기동성', b.mobility, '×${w.moveSpeed}'),
    ];
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                w.name,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(width: 10),
              const GradeBadge('E'),
              const Spacer(),
              Text('TTK ${ttk(w).toStringAsFixed(2)}초'),
            ],
          ),
          const SizedBox(height: 8),
          for (final (label, ratio, value) in rows)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: [
                  SizedBox(width: 72, child: Text(label)),
                  Expanded(
                    child: LinearProgressIndicator(
                      value: ratio,
                      minHeight: 8,
                      color: amberColor,
                      backgroundColor: panelColor,
                    ),
                  ),
                  SizedBox(
                    width: 84,
                    child: Text(value, textAlign: TextAlign.right),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 8),
          Text('장점  ${w.pros}'),
          Text('단점  ${w.cons}'),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: s.owns(w)
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
          ),
        ],
      ),
    );
  }
}
