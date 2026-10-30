// 웹에서 Auth 에뮬레이터 주소를 Firebase 초기화 전에 심어 둔다. 웹 파일은 조건부 import.
export 'auth_emulator_origin_stub.dart'
    if (dart.library.js_interop) 'auth_emulator_origin_web.dart';
