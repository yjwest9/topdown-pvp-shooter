import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'data/services/firebase_setup.dart';
import 'data/services/push_service.dart';
import 'ui/lobby/lobby_view.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // 몰입 모드: 상태바·내비바 숨김. 가장자리에서 쓸면 잠깐 보였다 다시 숨는다.
  // 가로 고정은 AndroidManifest의 sensorLandscape.
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  // 훈련소는 Firebase를 쓰지 않는다. 로그인·DB 연결은 방에 들어갈 때.
  await initFirebase(useEmulator: const bool.fromEnvironment('USE_EMULATOR'));
  // 공휴일 이벤트 알림 토픽 구독. 실패해도(권한 거부, 오프라인) 게임은 그대로.
  unawaited(
    FirebasePushService().subscribeEvents().then((_) {}, onError: (_) {}),
  );
  runApp(const ProviderScope(child: TopSoldierApp()));
}

class TopSoldierApp extends StatelessWidget {
  const TopSoldierApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TOP SOLDIER',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
      home: const LobbyView(),
    );
  }
}
