import 'package:flame_riverpod/flame_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'game/soldier_game.dart';

void main() {
  runApp(const ProviderScope(child: TopSoldierApp()));
}

class TopSoldierApp extends StatefulWidget {
  const TopSoldierApp({super.key});

  @override
  State<TopSoldierApp> createState() => _TopSoldierAppState();
}

class _TopSoldierAppState extends State<TopSoldierApp> {
  final _gameKey = GlobalKey<RiverpodAwareGameWidgetState<SoldierGame>>();
  final _game = SoldierGame();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TOP SOLDIER',
      debugShowCheckedModeBanner: false,
      home: RiverpodAwareGameWidget<SoldierGame>(key: _gameKey, game: _game),
    );
  }
}
