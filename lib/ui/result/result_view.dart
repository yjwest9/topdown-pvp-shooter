import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/match_stats.dart';
import '../../rules/match.dart';
import '../lobby/lobby_view_model.dart';
import 'result_view_model.dart';

class ResultView extends ConsumerWidget {
  const ResultView({super.key, required this.stats});

  final MatchStats stats;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vm = ResultViewModel(
      stats,
      holiday: ref.watch(holidayProvider).value,
    );
    final color = switch (stats.result) {
      MatchResult.win => const Color(0xFFE8B33A),
      MatchResult.lose => const Color(0xFFE0563F),
      MatchResult.draw => const Color(0xFFE3E6D8),
    };
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
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('로비로'),
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
