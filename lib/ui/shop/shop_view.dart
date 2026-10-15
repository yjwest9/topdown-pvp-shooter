import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../rules/balance.dart';
import '../format.dart';
import '../style.dart';
import 'shop_view_model.dart';

const _diamondColor = Color(0xFF7FD4F0);

/// 상점(홈 아래 메뉴 "상점", decisions 9·10장): 무료 골드(광고), 환전, 다이아 충전(준비 중).
class ShopView extends ConsumerWidget {
  const ShopView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(shopProvider);
    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: panelColor,
        toolbarHeight: 44,
        title: const Text('상점'),
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
      // 아래 안전 영역 없음: immersiveSticky에서 키보드·시스템 바가 한 번 뜨면 아래가 떠 보인다(홈과 같음).
      body: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Card(
                title: '무료 골드',
                icon: const Icon(Icons.monetization_on, color: amberColor),
                line: '+${commas(adRewardGold)} G · 1시간마다',
                child: _AdButton(s),
              ),
              _Card(
                title: '환전',
                icon: const Icon(Icons.diamond, color: _diamondColor),
                line: '${commas(exchangeGoldCost)} G → $exchangeDiamonds 다이아',
                child: _ExchangeButton(s),
              ),
              _Card(
                title: '다이아 충전',
                icon: const Icon(Icons.diamond, color: _diamondColor),
                line: '결제 준비 중',
                child: Column(
                  children: [
                    for (final n in const [100, 500, 1200])
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${commas(n)} 다이아',
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          const FilledButton(
                            onPressed: null,
                            child: Text('준비 중'),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({
    required this.title,
    required this.icon,
    required this.line,
    required this.child,
  });

  final String title;
  final Widget icon;
  final String line;
  final Widget child;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      margin: const EdgeInsets.all(4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: panelColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              icon,
              const SizedBox(width: 6),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            line,
            style: TextStyle(color: lightColor.withValues(alpha: 0.7)),
          ),
          const Spacer(),
          child,
        ],
      ),
    ),
  );
}

/// 59분 12초 → "59:12". 남은 1ms도 1초로 올려서 보여 준다(0:00인데 못 누르는 일 없게).
String _mmss(Duration d) {
  final s = (d.inMilliseconds + 999) ~/ 1000;
  return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
}

/// 광고 버튼. 쿨타임 글자를 1초마다 다시 그린다.
class _AdButton extends ConsumerStatefulWidget {
  const _AdButton(this.s);

  final ShopState s;

  @override
  ConsumerState<_AdButton> createState() => _AdButtonState();
}

class _AdButtonState extends ConsumerState<_AdButton> {
  late final Timer _tick;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) => setState(() {}));
  }

  @override
  void dispose() {
    _tick.cancel();
    super.dispose();
  }

  Future<void> _watch() async {
    final got = await ref.read(shopProvider.notifier).watchAd();
    if (!mounted || got == AdReward.none) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(switch (got) {
            AdReward.paid => '+${commas(adRewardGold)} G',
            AdReward.offline => connectionErrorText,
            _ => '보상을 받지 못했습니다. 인터넷 연결을 확인해 주세요',
          }),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    final left = s.cooldownLeft(DateTime.now().millisecondsSinceEpoch);
    Widget disabled(String text) =>
        FilledButton(onPressed: null, child: Text(text));
    if (s.ad == AdStatus.unsupported) return disabled('앱에서만 가능');
    if (left > Duration.zero) return disabled('다시 받기까지 ${_mmss(left)}');
    return switch (s.ad) {
      AdStatus.loading => disabled('광고 준비 중…'),
      AdStatus.failed => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('광고를 불러오지 못했습니다', textAlign: TextAlign.center),
          OutlinedButton(
            onPressed: () =>
                unawaited(ref.read(shopProvider.notifier).loadAd()),
            child: const Text('다시 시도'),
          ),
        ],
      ),
      _ => FilledButton(
        onPressed: s.busy ? null : () => unawaited(_watch()),
        child: Text('광고 보고 ${commas(adRewardGold)}G'),
      ),
    };
  }
}

class _ExchangeButton extends ConsumerWidget {
  const _ExchangeButton(this.s);

  final ShopState s;

  Future<void> _exchange(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('환전'),
        content: Text(
          '${commas(exchangeGoldCost)} G로 $exchangeDiamonds 다이아를 받을까요?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('환전'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final done = await ref.read(shopProvider.notifier).exchange();
    if (done && context.mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('+$exchangeDiamonds 다이아')));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) => FilledButton(
    onPressed: s.canExchange && !s.busy
        ? () => unawaited(_exchange(context, ref))
        : null,
    child: Text(
      '$exchangeDiamonds 다이아 받기 — ${commas(exchangeGoldCost)}G',
      textAlign: TextAlign.center,
    ),
  );
}
