import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'data/repositories/auth_repository.dart';
import 'data/repositories/connection_repository.dart';
import 'data/repositories/friend_repository.dart';
import 'data/repositories/room_repository.dart';
import 'data/services/firebase_setup.dart';
import 'data/services/push_service.dart';
import 'ui/home/home_view.dart';
import 'ui/restart_scope.dart';

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
  runApp(const RestartScope(child: ProviderScope(child: TopSoldierApp())));
}

class TopSoldierApp extends ConsumerStatefulWidget {
  const TopSoldierApp({super.key});

  @override
  ConsumerState<TopSoldierApp> createState() => _TopSoldierAppState();
}

class _TopSoldierAppState extends ConsumerState<TopSoldierApp>
    with WidgetsBindingObserver {
  bool _wasAway = false;
  StreamSubscription<Object?>? _online;

  ConnectionRepository get _connection =>
      ref.read(roomRepositoryProvider).connection;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // DB 연결이 켜지고 꺼지는 때를 로그로 남긴다(화면엔 안 보임). Firebase가 없으면(위젯 테스트) 건너뛴다.
    try {
      _connection.watch().listen(
        (c) => debugPrint(
          '[conn] ${DateTime.now().toIso8601String()} connected=$c',
        ),
      );
    } catch (_) {}
    // 친구 목록의 접속 표시(decisions 18장). 로그인이 안 되면(오프라인·위젯 테스트) 건너뛴다.
    unawaited(
      ref.read(authRepositoryProvider).signIn().then((uid) {
        if (!mounted) return;
        _online = ref.read(friendRepositoryProvider).keepOnline(uid);
      }, onError: (_) {}),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_online?.cancel());
    super.dispose();
  }

  /// 앱이 다시 앞으로 올 때 DB가 끊겨 있으면 다시 붙인다(로컬 에뮬레이터 모드에선 네트워크가
  /// 돌아와도 스스로 안 붙었다, demo-risks).
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (_wasAway) {
        unawaited(_connection.ensureConnected().then((_) {}, onError: (_) {}));
      }
      _wasAway = false;
    } else if (state == AppLifecycleState.paused) {
      _wasAway = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TOP SOLDIER',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
      home: const HomeView(),
    );
  }
}
