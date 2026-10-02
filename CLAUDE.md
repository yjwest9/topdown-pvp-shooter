# TOP SOLDIER — 프로젝트 규칙

2D 탑다운 실시간 PvP 슈터 (Flutter + Flame). 스페셜솔져(2015~2020)에서 영감을 받은 오리지널 게임.
국비과정 마지막 개인 프로젝트. **최종 발표 2026-10-22**, Google Play 비공개 테스트 배포가 목표.

- 패키지: `com.yjseo.topsoldier` (플레이스토어 업로드 후 변경 불가)
- 플랫폼: Android (배포), Web/Chrome (멀티플레이 테스트용). iOS는 범위 밖.
- 모든 게임 설계 결정은 `docs/decisions.md`에 있다. **작업 전에 관련 항목을 읽고, 거기 적힌 대로 구현한다.** 결정과 다르게 하고 싶으면 먼저 사용자에게 묻는다.
- 진행 상황은 `docs/progress.md`. 작업을 끝낼 때마다 갱신한다.

## 사용자에 대해

- Flutter/Dart는 수업에서 흐름만 익힌 수준. AI와 함께 작업한다.
- 설명은 **한국어로, 예시 중심으로 짧게**. 무엇을 왜 바꿨는지 한두 줄로 알려준다.
- 사용자가 직접 확인해야 하는 것(에뮬레이터 화면, 조작감)은 확인 방법을 구체적으로 알려준다.

## 명령어

```bash
flutter pub get
flutter run -d emulator-5554        # 안드로이드 에뮬레이터 (기기 ID는 flutter devices로 확인)
flutter run -d chrome               # 웹 (멀티플레이 2번째 클라이언트)
dart format .
flutter analyze
flutter test
firebase emulators:start            # Firebase 로컬 에뮬레이터 (설정 후)
```

## 완료 기준 (이걸 못 넘으면 "완료"라고 말하지 않는다)

1. `dart format .` 적용
2. `flutter analyze` 경고/에러 0개
3. `flutter test` 전부 통과
4. 게임 동작 변경이면: 무엇을 어떻게 눈으로 확인하면 되는지 사용자에게 안내

## 아키텍처

Flutter 공식 권장 아키텍처(MVVM + Repository + Service) + 게임 규칙 계층 분리.

```
lib/
├─ main.dart
├─ data/
│  ├─ services/       외부 연결만, 상태 없음 (Firebase, prefs, http, ads, iap)
│  ├─ repositories/   앱이 데이터를 얻는 단일 창구
│  └─ models/         불변 클래스 + copyWith
├─ rules/             순수 Dart 게임 규칙과 밸런스 수치 (Flutter/Flame import 금지)
├─ ui/<기능>/         <기능>_view.dart + <기능>_view_model.dart 한 쌍
└─ game/              Flame (FlameGame + RiverpodGameMixin)
   ├─ components/
   └─ net/            match_sync: room_repository로 상태 송수신
test/                 lib/ 구조를 그대로 따라간다
```

**의존 방향 (어기지 말 것)**
- `ui`, `game` → `data/repositories`, `rules`
- `repositories` → `services`, `models`
- `rules` → 아무것도 import하지 않음 (dart:math 정도만)
- `ui`와 `game`은 `services`를 직접 부르지 않는다

## 코딩 규칙

- 상태관리: **Riverpod 3**. `Notifier` / `AsyncNotifier`를 **코드 생성 없이** 직접 작성. `@riverpod`, `build_runner`, `freezed` 쓰지 않는다.
- Flame 연동: `flame_riverpod` (`RiverpodAwareGameWidget`, `RiverpodGameMixin`, `RiverpodComponentMixin`).
- 밸런스 수치(무기, 캐릭터, 자세, 경제, 확률 상한)는 **`lib/rules/balance.dart` 한 곳**에만 둔다. 코드 곳곳에 숫자를 박지 않는다. 나중에 Firestore 설정으로 덮어쓸 수 있는 구조로.
- 무기·캐릭터는 데이터(표의 한 줄)로 정의한다. 무기마다 클래스를 새로 만들지 않는다.
- 요청받지 않은 기능, 추상화, 설정 옵션을 추가하지 않는다. 지금 필요한 만큼만.
- 기존 코드를 고칠 때는 요청과 관련된 줄만 바꾼다. 관련 없는 정리/리팩터링은 하지 말고 제안만 한다.
- 파일명 snake_case, 클래스 PascalCase.

## 테스트

- `rules/`는 **테스트 먼저** 쓰고 구현한다. 수치는 `docs/decisions.md` 기준.
- 밸런스 불변식 테스트 유지: 크리티컬 확률 ≤ 상한(30%), 미스 확률 0~20%, 최대 성장 격차 ≤ 총알 2발 등.
- 게임 동작(점프로 상자 넘기, 앉으면 엄폐 등)은 `flame_test`로 게임 루프를 돌려서 검증.
- Firebase 연동 로직은 Firebase 로컬 에뮬레이터에서 테스트. 실서버 데이터로 테스트하지 않는다.

## Git (GitHub Flow)

- 기본 브랜치는 `main` 하나. **main은 항상 실행되고 테스트가 통과하는 상태.**
- 기능마다 브랜치: `feat/…`, `fix/…`, `docs/…`, `chore/…`
- 커밋 메시지: `feat: 플레이어 점프 추가` 처럼 머리말 + 한국어 요약.
- 작업이 끝나면 완료 기준 통과 확인 후 main에 병합(PR 또는 로컬 병합, 사용자가 정한 방식).
- 플레이스토어 업로드 빌드에는 태그 `v0.x.y`를 붙이고 `pubspec.yaml`의 version(빌드 번호 포함)을 올린다.
- 사용자가 요청하기 전에는 push, 태그, 병합을 하지 않는다.

## 하지 말 것

- 사용자에게 묻지 않고 패키지 추가/버전 변경
- API 키, 비밀값을 코드나 커밋에 넣기 (`--dart-define` 또는 gitignore된 파일 사용)
- 실제 AdMob 광고 단위 ID 사용 (개발 중엔 Google 테스트 ID만)
- 원작 스페셜솔져의 이름, 로고, 그래픽, 실제 총기 상표명 사용 (가상 이름 사용)
- `docs/decisions.md`와 다른 규칙으로 구현하기
- 테스트를 통과시키려고 테스트를 약화/삭제하기
