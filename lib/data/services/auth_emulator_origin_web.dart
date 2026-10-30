import 'dart:js_interop';

@JS('sessionStorage')
external _Storage get _sessionStorage;

extension type _Storage._(JSObject _) implements JSObject {
  external void setItem(JSString key, JSString value);
}

/// firebase_auth_web은 `Firebase.initializeApp` 안에서 Auth를 먼저 초기화한다. 그 뒤의
/// `useAuthEmulator`는 JS SDK가 `auth/emulator-config-failed`로 거절하는데 플러그인이 이
/// 오류를 삼켜서, 로그인이 조용히 실서버로 갔다. 플러그인은 초기화 때 이 sessionStorage
/// 값이 있으면 먼저 에뮬레이터에 연결한다(localhost + 디버그 모드에서만).
void presetAuthEmulatorOrigin(String origin) {
  _sessionStorage.setItem('[DEFAULT]-firebaseEmulatorOrigin'.toJS, origin.toJS);
}
