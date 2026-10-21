import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/match_stats.dart';
import '../../data/models/profile.dart';
import '../../data/repositories/ad_repository.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/profile_repository.dart';
import '../../data/repositories/room_repository.dart';
import '../../rules/balance.dart';
import '../../rules/match.dart';
import '../../rules/rewards.dart';
import '../format.dart';
import '../home/home_view_model.dart';
import '../shop/shop_view_model.dart' show AdStatus;
import 'result_view_model.dart';

/// 매치 결과를 프로필에 더한다. 저장하지 않는 매치(훈련소)거나 실패하면 null.
Future<({Profile before, Profile after})?> saveMatchResult(
  WidgetRef ref,
  ResultViewModel vm,
) async {
  if (!vm.saves) return null;
  try {
    final uid = await ref.read(authRepositoryProvider).signIn();
    return await ref
        .read(profileRepositoryProvider)
        .applyMatch(uid, vm.stats.matchId, vm.applyTo);
  } catch (_) {
    return null; // 오프라인 등. 보상 글자는 그대로 보인다.
  }
}

class ResultView extends ConsumerStatefulWidget {
  const ResultView({super.key, required this.stats, this.mode = MatchMode.pvp});

  final MatchStats stats;
  final MatchMode mode;

  @override
  ConsumerState<ResultView> createState() => _ResultViewState();
}

class _ResultViewState extends ConsumerState<ResultView> {
  /// 저장한 전후 프로필(레벨업 표시). 이미 저장했거나 실패하면 null.
  late final Future<({Profile before, Profile after})?> _saved = _save();

  Future<({Profile before, Profile after})?> _save() async {
    final holiday = await ref
        .read(holidayProvider.future)
        .catchError((_) => null);
    if (!mounted) return null;
    return saveMatchResult(
      ref,
      ResultViewModel(widget.stats, holiday: holiday, mode: widget.mode),
    );
  }

  /// 결과 화면 광고(decisions 10장). 이 판에 실제로 저장된 골드(0이면 버튼 없음).
  int _matchGold = 0;
  AdStatus _ad = AdStatus.unsupported;
  bool _busy = false;
  bool _claimed = false;

  @override
  void initState() {
    super.initState();
    unawaited(_saved.then(_prepareAd));
  }

  /// 결과 화면이 뜨고 보상이 저장된 뒤에야 광고를 불러온다(매치 중엔 안 불러옴).
  Future<void> _prepareAd(({Profile before, Profile after})? saved) async {
    final ads = ref.read(adRepositoryProvider);
    final gold = saved == null ? 0 : saved.after.gold - saved.before.gold;
    if (!mounted || gold <= 0 || !ads.supported) return;
    setState(() {
      _matchGold = gold;
      _ad = AdStatus.loading;
    });
    final ok = await ads.load();
    if (mounted) setState(() => _ad = ok ? AdStatus.ready : AdStatus.failed);
  }

  /// 끝까지 봤으면(보상 콜백) 이 판 골드를 한 번 더. 닫기만 했으면 아무 일 없음.
  Future<void> _watchAd() async {
    final ads = ref.read(adRepositoryProvider);
    final connection = ref.read(roomRepositoryProvider).connection;
    const failed = '보상을 받지 못했습니다. 인터넷 연결을 확인해 주세요';
    setState(() => _busy = true);
    String? message;
    var reload = true;
    try {
      // 광고를 보고도 보상을 못 받는 일이 없게, 연결이 없으면 광고 전에 알린다.
      if (!await connection.ensureConnected()) {
        reload = false;
        message = connectionErrorText;
        return;
      }
      if (!await ads.show()) return;
      try {
        if (!await connection.ensureConnected()) {
          message = failed;
          return;
        }
        final bonus = resultAdBonus(_matchGold, claimed: _claimed);
        await ref
            .read(profileRepositoryProvider)
            .addGold(await ref.read(authRepositoryProvider).signIn(), bonus)
            .timeout(requestTimeout);
        _claimed = true;
        message = '+${commas(bonus)} G';
      } catch (e) {
        debugPrint('결과 광고 보상 저장 실패: $e');
        message = failed;
      }
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          if (reload && !_claimed) _ad = AdStatus.loading;
        });
        if (message != null) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(SnackBar(content: Text(message)));
        }
        if (reload && !_claimed) {
          final ok = await ads.load();
          if (mounted) {
            setState(() => _ad = ok ? AdStatus.ready : AdStatus.failed);
          }
        }
      }
    }
  }

  /// 보상 표시 바로 아래 버튼. 보상이 없거나 웹이거나 광고를 못 불렀으면 안 보인다.
  Widget _doubleButton() {
    if (_matchGold <= 0 || _ad == AdStatus.unsupported) {
      return const SizedBox.shrink();
    }
    if (_claimed) {
      return const FilledButton(onPressed: null, child: Text('2배 받음'));
    }
    return switch (_ad) {
      AdStatus.failed || AdStatus.unsupported => const SizedBox.shrink(),
      AdStatus.loading => const FilledButton(
        onPressed: null,
        child: Text('광고 준비 중…'),
      ),
      AdStatus.ready => FilledButton(
        onPressed: _busy ? null : () => unawaited(_watchAd()),
        child: const Text('광고 보고 보상 2배'),
      ),
    };
  }

  @override
  Widget build(BuildContext context) {
    final vm = ResultViewModel(
      widget.stats,
      holiday: ref.watch(holidayProvider).value,
      mode: widget.mode,
    );
    final color = switch (widget.stats.result) {
      MatchResult.win => const Color(0xFFE8B33A),
      MatchResult.lose => const Color(0xFFE0563F),
      MatchResult.draw => const Color(0xFFE3E6D8),
    };
    const amber = TextStyle(
      color: Color(0xFFE8B33A),
      fontSize: 18,
      fontWeight: FontWeight.w800,
    );
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: SizedBox(
              width: 320,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    vm.title,
                    style: TextStyle(
                      fontSize: 44,
                      fontWeight: FontWeight.w900,
                      color: color,
                    ),
                  ),
                  const SizedBox(height: 16),
                  for (final (label, value) in vm.rows)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [Text(label), Text(value)],
                      ),
                    ),
                  const SizedBox(height: 12),
                  if (vm.rewarded)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        Text(vm.goldText, style: amber),
                        Text(vm.expText, style: amber),
                      ],
                    )
                  else
                    const Text('친선전 · 보상 없음'),
                  if (_matchGold > 0 && _ad != AdStatus.failed) ...[
                    const SizedBox(height: 12),
                    _doubleButton(),
                  ],
                  FutureBuilder(
                    future: _saved,
                    builder: (context, snap) {
                      final saved = snap.data;
                      final text = saved == null
                          ? null
                          : ResultViewModel.levelUpText(
                              saved.before,
                              saved.after,
                            );
                      if (text == null) return const SizedBox(height: 8);
                      return Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(text, style: amber.copyWith(fontSize: 24)),
                      );
                    },
                  ),
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: () =>
                        Navigator.of(context)
                            .popUntil((route) => route.isFirst),
                    child: const Text('홈으로'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
