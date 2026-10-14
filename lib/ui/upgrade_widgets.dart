import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../rules/balance.dart';
import '../rules/upgrade.dart';
import 'format.dart';
import 'style.dart';

/// 강화 카드: "+2 → +3", 비용·성공률, 능력치 변화([change]), [강화]. +5면 최대, 골드 부족이면 막힘.
/// 무기·캐릭터 화면이 같이 쓴다(비용·성공률도 같은 값, decisions 8장).
class UpgradePanel extends StatelessWidget {
  const UpgradePanel({
    super.key,
    required this.level,
    required this.gold,
    required this.busy,
    required this.change,
    required this.onUpgrade,
  });

  final int level;
  final int gold;
  final bool busy;

  /// "데미지 10.0 → 10.2"처럼 다음 단계에서 바뀌는 것.
  final String change;
  final VoidCallback onUpgrade;

  @override
  Widget build(BuildContext context) {
    if (level >= maxUpgradeLevel) {
      return const Text(
        '최대 강화 (+5)',
        style: TextStyle(color: amberColor, fontWeight: FontWeight.w900),
      );
    }
    final cost = upgradeCost(level);
    final enough = gold >= cost;
    final chance = (upgradeChance(level) * 100).round();
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
          Text(change, style: const TextStyle(fontSize: 12)),
          const SizedBox(height: 6),
          FilledButton.tonal(
            onPressed: enough && !busy ? onUpgrade : null,
            child: Text(enough ? '강화' : '골드 부족'),
          ),
        ],
      ),
    );
  }
}

/// 강화 결과 연출(약 1초): 성공이면 이름 뒤가 빛나며 "강화 성공!", 실패면 흔들리며 "강화 실패".
class UpgradeFlash extends StatefulWidget {
  const UpgradeFlash({
    super.key,
    required this.seq,
    required this.result,
    required this.child,
  });

  /// 바뀔 때마다 한 번 재생.
  final int seq;
  final UpgradeOutcome? result;
  final Widget child;

  @override
  State<UpgradeFlash> createState() => _UpgradeFlashState();
}

class _UpgradeFlashState extends State<UpgradeFlash>
    with SingleTickerProviderStateMixin {
  late final _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );

  @override
  void didUpdateWidget(UpgradeFlash old) {
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
