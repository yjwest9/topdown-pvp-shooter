# 1대1 멀티플레이 테스트 (Firebase 로컬 에뮬레이터)

실서버 데이터를 쓰지 않고, PC에서 도는 Auth·Database 에뮬레이터에 크롬과 안드로이드 에뮬레이터를 붙여서 1대1을 해 본다.

## 준비 (처음 한 번)

- Firebase CLI: `npm install -g firebase-tools` (확인: `firebase --version`)
- **JDK 21** (에뮬레이터 실행에 필요. 에뮬레이터는 Java 11~21만 지원하고, 더 높은 버전에서는 DB 에뮬레이터가 내부 오류로 멈춘 적이 있다). 확인: `java -version`, `JAVA_HOME`이 JDK 21을 가리키는지
- 프로젝트 설정은 커밋돼 있다: `firebase.json`(에뮬레이터 포트), `.firebaserc`(프로젝트 `topsoldier`), `database.rules.json`(DB 규칙)

## 1. 에뮬레이터 켜기 (터미널 1)

```bash
firebase emulators:start --only auth,database
```

- Auth `127.0.0.1:9099`, Database `127.0.0.1:9000`, 관리 화면 http://127.0.0.1:4000
- `database.rules.json`을 고치면 에뮬레이터가 바로 다시 읽는다.
- 끄면 데이터는 사라진다(매번 빈 DB로 시작).

## 2. 안드로이드 에뮬레이터 실행 (터미널 2)

```bash
flutter run -d emulator-5554 --dart-define=USE_EMULATOR=true
```

- 앱이 `10.0.2.2`(안드로이드 에뮬레이터에서 본 PC)로 접속한다.
- debug 빌드만 HTTP 접속을 허용한다(`android/app/src/debug/AndroidManifest.xml`). release로는 에뮬레이터 모드를 쓸 수 없다.

## 3. 크롬 실행 (터미널 3)

```bash
flutter run -d chrome --dart-define=USE_EMULATOR=true
```

- 크롬은 `localhost`로 접속한다.
- 웹 조작: WASD 이동, ←→ 회전, Space 점프, C 앉기, Shift 달리기, ↑ 사격.

## 4. 1대1 순서

1. 한쪽(예: 안드로이드)에서 **방 만들기** → 4자리 코드가 크게 뜬다.
2. 다른 쪽(크롬)에서 코드를 입력하고 **코드로 입장**.
3. 양쪽 대기실에 이름 두 개(`Soldier####`)가 보이면 방장 화면에 **시작** 버튼이 켜진다.
4. **시작** → 둘 다 게임 화면. 방장은 남쪽, 참가자는 북쪽에서 서로 마주 보고 시작한다.
5. 확인할 것:
   - 상대(빨간 원)가 부드럽게 움직이고 회전하는지
   - 점프하면 상대 화면에서 커졌다 작아지는지, 앉으면 링이 보이는지, 상자 위에 서면 커 보이는지
   - 낮은 상자 바로 뒤에 앉으면 상대 화면에서 사라지는지
   - 쏘면 상대 화면에도 같은 총알이 날아가는지(지금은 맞아도 아무 일 없음)
6. 한쪽 앱을 끄거나 **나가기** → 다른 쪽에 "상대가 나갔습니다"가 뜨고 2초 뒤 로비로 돌아간다.

## 5. 전투·매치 확인 (feat/match-combat)

1. 서로 쏴서 상대 머리 위 체력 바와 내 화면 아래 HP가 줄어드는지. 맞으면 화면 가장자리가 빨갛게 깜빡인다.
2. 데미지 숫자가 상대 위에 뜨는지, 크리티컬은 크고 노란 숫자, 빗나가면 MISS.
3. 체력 0 → "전사" + 5초 카운트다운 → 내 진영(방장 남쪽, 참가자 북쪽)에서 부활.
4. 부활 직후 3초 동안 몸이 깜빡이고(상대 화면에서도) 총알을 맞아도 체력이 안 준다.
5. 위 가운데 `A 1 : 0 B`와 남은 시간, 오른쪽 위 킬 로그(`이름 ▸ 이름  무기  CRIT`).
6. 3분이 지나거나 한 팀이 20킬 → 둘 다 결과 화면(승리/패배/무승부, 킬·데스·명중률·크리) → [로비로].
7. 매치 중 한쪽이 앱을 끄거나 나가기 → 남은 쪽에 "상대가 나갔습니다" 후 승리 결과 화면.

20킬을 직접 채우기 어렵다면 관리 화면(http://127.0.0.1:4000/database)에서 `rooms/{코드}/score/A`를 19로 바꾸고 한 번 더 죽이면 된다.

## 데이터 보기

http://127.0.0.1:4000/database 에서 `rooms/{코드}` 아래 `meta`, `players`, `states`(초당 15회 갱신), `shots`, `hp`, `kills`, `score`를 볼 수 있다.

## 안 될 때

- 방 만들기·코드로 입장 버튼이 회색으로 멈춤: 에뮬레이터를 다시 켜서 예전 계정이 사라진 경우. 지금은 앱이 알아서 새로 로그인한다. 그래도 멈추면 앱 데이터 지우기(`adb shell pm clear com.yjseo.topsoldier`) 후 다시 실행.
- 로비에서 "연결하지 못했습니다": 에뮬레이터가 켜져 있는지, `--dart-define=USE_EMULATOR=true`를 넣었는지 확인.
- "Permission denied": `database.rules.json` 규칙에 맞지 않는 쓰기. 에뮬레이터 터미널에 어느 경로인지 나온다.
- 상대가 안 보임: 관리 화면에서 `states/{uid}`가 계속 바뀌는지 확인.
- 몇 초 뒤 상대가 멈춤: 안드로이드에서 `useDatabaseEmulator`를 쓰면 생기는 문제라 `firebase_setup.dart`에서 에뮬레이터 주소로 직접 연결한다. 그 코드를 바꾸지 않았는지 확인.
- 에뮬레이터 로그(`database-debug.log`)에 NullPointerException 또는 DB가 30초씩 멈춤: `java -version`이 21인지 확인.
