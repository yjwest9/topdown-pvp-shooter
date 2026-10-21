import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/profile.dart';
import '../../game/net/match_sync.dart';
import '../../rules/balance.dart';
import '../../rules/character.dart';
import '../../rules/map_select.dart';
import '../../rules/rewards.dart';
import '../../rules/upgrade.dart';
import '../character/character_view.dart';
import '../character_figure.dart';
import '../format.dart';
import '../loadout/loadout_view.dart';
import '../loadout/loadout_view_model.dart';
import '../lobby/lobby_view.dart';
import '../map_chips.dart';
import '../match/match_view.dart';
import '../matchmaking/matchmaking_view.dart';
import '../settings/settings_view.dart';
import '../settings/settings_view_model.dart';
import '../shop/shop_view.dart';
import '../style.dart';
import 'home_view_model.dart';
import 'nickname_form.dart';

/// 홈(가로). 첫 실행이면 닉네임 입력부터.
class HomeView extends ConsumerWidget {
  const HomeView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(homeProvider);
    // 설정은 매치를 열 때 바로 쓰도록 미리 읽어 둔다.
    ref.watch(settingsProvider);
    return Scaffold(
      backgroundColor: bgColor,
      // 아래는 안전 영역을 안 둔다: immersiveSticky에서 키보드·시스템 바가 한 번 뜨면 탭바가 밑에서 떠 보였다.
      body: SafeArea(
        bottom: false,
        child: s.needsNickname
            ? const Center(child: NicknameForm(first: true))
            : _Home(s),
      ),
    );
  }
}

class _Home extends ConsumerWidget {
  const _Home(this.s);

  final HomeState s;

  Future<void> _play(
    BuildContext context, {
    MatchSync? match,
    BotDifficulty? bot,
    MapInfo map = duelMap,
  }) => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => MatchView(
        match: match,
        bot: bot,
        mapInfo: map,
        mode: bot == null ? MatchMode.training : MatchMode.bot,
      ),
    ),
  );

  Future<void> _playBot(
    BuildContext context,
    WidgetRef ref,
    BotDifficulty bot, {
    MapInfo map = duelMap,
  }) async {
    final room = await ref.read(homeProvider.notifier).botRoom();
    if (!context.mounted) return;
    await _play(
      context,
      match: MatchSync(
        rooms: room.rooms,
        code: room.code,
        uid: 'me',
        isHost: true,
      ),
      bot: bot,
      map: map,
    );
  }

  /// 빠른 대전. 30초 넘게 못 찾아 "봇과 대전"을 누르면 보통 봇전으로.
  Future<void> _quickMatch(BuildContext context, WidgetRef ref) async {
    final bot = await Navigator.of(context)
        .push<bool>(MaterialPageRoute(builder: (_) => const MatchmakingView()));
    if (bot == true && context.mounted) {
      await _playBot(context, ref, BotDifficulty.normal);
    }
  }

  Future<void> _chooseBot(BuildContext context, WidgetRef ref) async {
    var map = duelMap.id;
    final bot = await showDialog<BotDifficulty>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => SimpleDialog(
          title: const Text('봇전 난이도'),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
              child: MapChips(
                selected: map,
                onSelected: (id) => setState(() => map = id),
              ),
            ),
            for (final (d, label) in [
              (BotDifficulty.easy, '쉬움'),
              (BotDifficulty.normal, '보통'),
              (BotDifficulty.hard, '어려움'),
            ])
              SimpleDialogOption(
                onPressed: () => Navigator.of(context).pop(d),
                child: Text(label),
              ),
          ],
        ),
      ),
    );
    if (bot != null && context.mounted) {
      await _playBot(context, ref, bot, map: mapById(map));
    }
  }

  void _open(BuildContext context, Widget page) => unawaited(
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page)),
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      children: [
        _TopBar(s),
        if (s.showEventBanner)
          Container(
            width: double.infinity,
            color: amberColor,
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Text(
              '${s.holiday!.name} · 공휴일 보상 $holidayRewardMultiplier배!',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: bgColor,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: Row(
              children: [
                Expanded(flex: 3, child: _Character(s.profile)),
                const SizedBox(width: 24),
                Expanded(
                  flex: 2,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: amberColor,
                          foregroundColor: bgColor,
                          padding: const EdgeInsets.symmetric(vertical: 22),
                          textStyle: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        onPressed: () => unawaited(_quickMatch(context, ref)),
                        child: const Text('빠른 대전'),
                      ),
                      const SizedBox(height: 10),
                      OutlinedButton(
                        onPressed: () => unawaited(
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => const LobbyView(),
                            ),
                          ),
                        ),
                        child: const Text('방 만들기·코드 입장'),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () =>
                                  unawaited(_chooseBot(context, ref)),
                              child: const Text('봇전'),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => unawaited(_play(context)),
                              child: const Text('훈련소'),
                            ),
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
        Container(
          color: panelColor,
          child: Row(
            children: [
              for (final (icon, name, page) in [
                (Icons.gps_fixed, '무기', const LoadoutView()),
                (Icons.person, '캐릭터', const CharacterView()),
                (Icons.storefront, '상점', const ShopView()),
                (Icons.settings, '설정', const SettingsView()),
              ])
                Expanded(
                  child: TextButton.icon(
                    style: TextButton.styleFrom(foregroundColor: lightColor),
                    onPressed: () => _open(context, page),
                    icon: Icon(icon, size: 18),
                    label: Text(name),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar(this.s);

  final HomeState s;

  /// 프로필 카드: 전적 + 닉네임 변경.
  void _showCard(BuildContext context) => unawaited(
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(s.profile.nickname),
        content: SizedBox(
          width: 300,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final (label, value) in s.record)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [Text(label), Text(value)],
                  ),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              unawaited(
                showDialog<void>(
                  context: context,
                  builder: (_) =>
                      const AlertDialog(content: NicknameForm(first: false)),
                ),
              );
            },
            child: const Text('닉네임 변경'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('닫기'),
          ),
        ],
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final p = s.profile;
    return Container(
      color: panelColor,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          Flexible(
            child: InkWell(
              onTap: () => _showCard(context),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      p.nickname,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: lightColor,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.edit, size: 14, color: lightColor),
                ],
              ),
            ),
          ),
          const SizedBox(width: 16),
          InkWell(
            onTap: () => _showCard(context),
            child: Row(
              children: [
                Text(
                  'Lv.${p.level}',
                  style: const TextStyle(
                    color: amberColor,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 120,
                  child: LinearProgressIndicator(
                    value: s.expRatio,
                    minHeight: 6,
                    color: amberColor,
                    backgroundColor: bgColor,
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          const Icon(Icons.monetization_on, size: 18, color: amberColor),
          const SizedBox(width: 4),
          Text(commas(p.gold), style: const TextStyle(color: lightColor)),
          const SizedBox(width: 16),
          const Icon(Icons.diamond, size: 18, color: Color(0xFF7FD4F0)),
          const SizedBox(width: 4),
          Text(commas(p.diamond), style: const TextStyle(color: lightColor)),
        ],
      ),
    );
  }
}

/// 내 병사(게임 속 모양을 크게) + 주무기 이름과 등급 배지.
class _Character extends StatelessWidget {
  const _Character(this.profile);

  final Profile profile;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Expanded(
          child: LayoutBuilder(
            // 정면에서 서 있는 모습 + 장착 주무기(decisions 8장). 벡터라 키워도 선명하다.
            builder: (context, box) => Center(
              child: CharacterFigure(
                profile.equippedCharacter,
                weaponId: equippedWeapons(profile).primary.id,
                height: min(box.maxHeight, box.maxWidth * 1.6),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 장착 캐릭터 이름 + 단계(decisions 8장).
            Text(
              withLevel(
                characterStats(
                  profile.equippedCharacter,
                  profile.equippedCharacterLevel,
                ).name,
                profile.equippedCharacterLevel,
              ),
              style: const TextStyle(
                color: amberColor,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(width: 12),
            GradeBadge(profile.byId(profile.primaryId)?.grade ?? 'E'),
            const SizedBox(width: 8),
            Text(
              withLevel(
                equippedWeapons(profile).primary.name,
                equippedWeapons(profile).primaryLevel,
              ),
              style: const TextStyle(
                color: lightColor,
                fontWeight: FontWeight.w800,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
