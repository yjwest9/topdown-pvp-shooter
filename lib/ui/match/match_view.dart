import 'dart:async';

import 'package:flame_riverpod/flame_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/match_stats.dart';
import '../../data/repositories/profile_repository.dart';
import '../../data/repositories/sound_repository.dart';
import '../../game/components/minimap.dart';
import '../../game/net/match_sync.dart';
import '../../game/soldier_game.dart';
import '../../rules/balance.dart';
import '../../rules/character.dart';
import '../../rules/map_select.dart';
import '../../rules/match.dart';
import '../../rules/rewards.dart';
import '../loadout/loadout_view_model.dart';
import '../result/result_view.dart';
import '../result/result_view_model.dart';
import '../settings/settings_view_model.dart';

/// 게임 화면. [match]가 없으면 오프라인 훈련소.
// ponytail: 뷰모델 없음. 할 일이 나가기뿐이고 그건 MatchSync가 한다. 화면 상태가 늘면 분리.
class MatchView extends ConsumerStatefulWidget {
  const MatchView({
    super.key,
    this.match,
    this.bot,
    this.mapInfo = duelMap,
    this.mode = MatchMode.training,
  });

  final MatchSync? match;

  /// 봇전 난이도. [match]는 메모리 DB 방.
  final BotDifficulty? bot;

  /// 1대1 맵(빠른 대전은 duel).
  final MapInfo mapInfo;

  /// 보상·나가기 규칙(빠른 대전만 중간에 나가면 패배).
  final MatchMode mode;

  @override
  ConsumerState<MatchView> createState() => _MatchViewState();
}

class _MatchViewState extends ConsumerState<MatchView> {
  final _gameKey = GlobalKey<RiverpodAwareGameWidgetState<SoldierGame>>();

  /// 감도·발사 방식·미니맵은 설정(홈에서 미리 읽어 둠), 무기는 로드아웃, 캐릭터는 장착 캐릭터.
  /// 못 읽었으면(오프라인 등) 기본값. 게임 중에 설정을 바꿔도 다음 매치부터.
  late final _game = () {
    final settings = ref.read(settingsProvider).value ?? const SettingsState();
    final profile = ref.read(profileProvider).value;
    final loadout = equippedWeapons(profile);
    return SoldierGame(
      match: widget.match,
      bot: widget.bot,
      mapInfo: widget.mapInfo,
      sensitivity: settings.sensitivity,
      primaryFireMode: settings.primaryFireMode,
      secondaryFireMode: settings.secondaryFireMode,
      minimapRotates: settings.minimapRotates,
      sound: ref.read(soundRepositoryProvider),
      soundEnabled: settings.soundEnabled,
      primary: loadout.primary,
      secondary: loadout.secondary,
      primaryGrade: loadout.primaryGrade,
      secondaryGrade: loadout.secondaryGrade,
      primaryLevel: loadout.primaryLevel,
      secondaryLevel: loadout.secondaryLevel,
      character: characterStats(
        profile?.equippedCharacter,
        profile?.equippedCharacterLevel ?? 0,
      ),
      onMinimapRotatesChanged: (rotates) => unawaited(
        ref.read(settingsProvider.notifier).setMinimapRotates(rotates),
      ),
    );
  }();
  String? _message;
  bool _exiting = false;

  @override
  void initState() {
    super.initState();
    widget.match?.onMatchEnd = (stats, {required opponentLeft}) async {
      if (opponentLeft) {
        setState(() => _message = '상대가 나갔습니다');
        await Future<void>.delayed(const Duration(seconds: 2));
      }
      await _exit(result: stats);
    };
  }

  /// 게임 안 설정: 감도·발사 방식·미니맵·효과음은 바로 적용(저장도), 나가기. 게임은 멈추지 않는다.
  Future<void> _openSettings() async {
    final leave = await showDialog<bool>(
      context: context,
      builder: (_) => _InGameSettings(_game),
    );
    if (leave == true && mounted) await _leave();
  }

  /// 나가기 버튼·뒤로 가기. 빠른 대전이면 확인 후 패배로 기록하고 나간다.
  Future<void> _leave() async {
    final match = widget.match;
    if (match != null && widget.mode == MatchMode.pvp) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          content: const Text('지금 나가면 패배로 기록됩니다.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('계속하기'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('나가기'),
            ),
          ],
        ),
      );
      if (ok != true || !mounted || _exiting) return;
      unawaited(
        saveMatchResult(
          ref,
          ResultViewModel(match.statsFor(MatchResult.lose), forfeit: true),
        ),
      );
    }
    await _exit();
  }

  /// 방을 나간다. [result]가 있으면(매치 끝) 결과 화면으로, 없으면(중간에 나감) 로비로.
  Future<void> _exit({MatchStats? result}) async {
    if (_exiting) return;
    _exiting = true;
    // 네트워크 오류로 나가기가 실패해도 화면은 넘어간다(안 그러면 0초에서 멈춤).
    try {
      await widget.match?.leave();
    } catch (_) {}
    if (!mounted) return;
    final nav = Navigator.of(context);
    if (result == null) {
      nav.pop();
    } else {
      unawaited(
        nav.pushReplacement(
          MaterialPageRoute<void>(
            builder: (_) => ResultView(stats: result, mode: widget.mode),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // 뒤로 가기도 나가기 버튼과 같이 방을 나간다.
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(_leave());
      },
      child: _body(),
    );
  }

  Widget _body() {
    return Scaffold(
      body: Stack(
        children: [
          RiverpodAwareGameWidget<SoldierGame>(key: _gameKey, game: _game),
          // 미니맵(1대1에만) 오른쪽, 없으면 왼쪽 위. Flame HUD처럼 화면 모서리 기준이라
          // SafeArea를 쓰지 않는다(카메라 구멍만큼 밀려서 폰에서 엉뚱한 자리에 보였다).
          Positioned(
            left: widget.match == null ? 4 : Minimap.side + 12,
            top: 4,
            child: IconButton(
              tooltip: '설정',
              onPressed: () => unawaited(_openSettings()),
              icon: const Icon(Icons.settings, color: Color(0xFFE3E6D8)),
            ),
          ),
          if (_message != null)
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 28,
                  vertical: 16,
                ),
                color: const Color(0xCC000000),
                child: Text(
                  _message!,
                  style: const TextStyle(
                    color: Color(0xFFE3E6D8),
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _InGameSettings extends ConsumerWidget {
  const _InGameSettings(this.game);

  final SoldierGame game;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(settingsProvider).value ?? const SettingsState();
    final vm = ref.read(settingsProvider.notifier);
    return AlertDialog(
      title: const Text('설정'),
      contentPadding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const SizedBox(width: 90, child: Text('감도')),
                  Expanded(
                    child: Slider(
                      value: s.sensitivity,
                      min: minSensitivity,
                      max: maxSensitivity,
                      divisions:
                          ((maxSensitivity - minSensitivity) / sensitivityStep)
                              .round(),
                      label: s.sensitivity.toStringAsFixed(1),
                      onChanged: (v) {
                        unawaited(vm.setSensitivity(v));
                        game.sensitivity = v;
                      },
                    ),
                  ),
                  Text(s.sensitivity.toStringAsFixed(1)),
                ],
              ),
              for (final (primary, label) in [(true, '주무기'), (false, '보조무기')])
                Row(
                  children: [
                    SizedBox(width: 90, child: Text(label)),
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
                      onSelectionChanged: (v) {
                        unawaited(vm.setFireMode(v.first, primary: primary));
                        if (primary) {
                          game.primaryFireMode = v.first;
                        } else {
                          game.secondaryFireMode = v.first;
                        }
                      },
                    ),
                  ],
                ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('효과음'),
                value: s.soundEnabled,
                onChanged: (v) {
                  unawaited(vm.setSoundEnabled(v));
                  game.soundEnabled = v;
                },
              ),
              if (game.match != null)
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('미니맵 회전'),
                  value: s.minimapRotates,
                  onChanged: (v) {
                    unawaited(vm.setMinimapRotates(v));
                    game.minimapRotates = v;
                  },
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: TextButton.styleFrom(foregroundColor: const Color(0xFFE0563F)),
          child: const Text('나가기'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('계속하기'),
        ),
      ],
    );
  }
}
