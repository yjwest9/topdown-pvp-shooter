import 'dart:async';

import 'package:flame/flame.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:topsoldier/rules/appearance.dart';

/// 모든 테스트가 시작하기 전에 게임 그림(`assets/images/`)을 실제로 불러 둔다.
/// 위젯 테스트의 가짜 시간 안에서는 그림 디코딩이 끝나지 않아서(게임 onLoad가 멈춤),
/// 테스트 밖(실제 시간)에서 미리 불러 두면 게임은 캐시에서 바로 받는다.
/// Flame은 게임이 닫힐 때 공용 그림 캐시를 비우므로 테스트마다 부른다(캐시가 있으면 바로 끝남).
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => Flame.images.loadAll(artFiles));
  await testMain();
}
