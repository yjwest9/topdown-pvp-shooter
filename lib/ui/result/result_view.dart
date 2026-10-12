import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/match_stats.dart';
import '../../data/models/profile.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/profile_repository.dart';
import '../../rules/match.dart';
import '../../rules/rewards.dart';
import '../home/home_view_model.dart';
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

  @override
  void initState() {
    super.initState();
    unawaited(_saved);
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
