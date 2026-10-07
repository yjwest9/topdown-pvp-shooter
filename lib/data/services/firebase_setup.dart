import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';

import '../../firebase_options.dart';

/// 앱이 쓰는 Realtime Database. [initFirebase] 뒤에 쓴다.
FirebaseDatabase get rtdb => _rtdb ?? FirebaseDatabase.instance;
FirebaseDatabase? _rtdb;

/// [useEmulator]면 로컬 Auth(9099)·Database(9000) 에뮬레이터에 연결한다.
/// 안드로이드 에뮬레이터에서 PC의 localhost는 10.0.2.2.
Future<void> initFirebase({required bool useEmulator}) async {
  final options = DefaultFirebaseOptions.currentPlatform;
  await Firebase.initializeApp(options: options);
  if (!useEmulator) return;
  if (kIsWeb) {
    await FirebaseAuth.instance.useAuthEmulator('localhost', 9099);
    FirebaseDatabase.instance.useDatabaseEmulator('localhost', 9000);
    return;
  }
  await FirebaseAuth.instance.useAuthEmulator('10.0.2.2', 9099);
  // 안드로이드는 useDatabaseEmulator를 쓰지 않는다. 플러그인이 호출마다 useEmulator를
  // 다시 적용해 매번 새 DB 연결이 생기고(20초에 444개), 리스너가 끊기고 앱이 죽었다.
  // 에뮬레이터 주소로 인스턴스를 직접 만들면 하나로 유지된다.
  final ns = Uri.parse(options.databaseURL!).host.split('.').first;
  _rtdb = FirebaseDatabase.instanceFor(
    app: Firebase.app(),
    databaseURL: 'http://10.0.2.2:9000?ns=$ns',
  );
}
