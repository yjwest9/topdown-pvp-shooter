# 진행 상황

작업이 끝날 때마다 맨 위에 추가한다. (날짜 / 한 것 / 다음 할 일 / 막힌 것)

## 2026-10-02 (자세 시스템 — main 병합)
- 한 것: `rules/stance.dart`(StanceState: 서기/걷기 30px/s 판정, 달리기 입력 0.3 이상·시작 시 앉기 해제, 앉기 토글(공중 불가, 달리는 중엔 바로 앉고 달리기 해제·이동 유지), 점프 0.5s·대기 0.75s, 상자 위 착지·걸어 내려오기·가장자리 0.03s 연장), `rules/cover.dart`(낮은 상자 엄폐·높은 벽 차단·피격 반경, 게임 연결 전), 플레이어 연출(점프 확대·그림자, 앉기 0.82배+링, 상자 위 1.18배), 조이스틱 달리기 원(80px 점선), HUD 자세 글자, JUMP/DUCK 버튼(누른 손가락은 회전 안 잡힘), 웹 키 Space/C/Ctrl/Shift, ←→ 회전 감도 반영. 터치 두 손가락(조이스틱+DUCK)·키보드 달리다 앉기 시나리오 테스트. 테스트 99개 통과.
- 다음: 사격.
- 막힌 것: 없음. 가장자리 연장은 데모와 같아서 입력 없이 가장자리에 멈추면 살짝 뜬 채(JUMP)로 남음 — 움직이면 내려옴.

## 2026-10-02 (플레이어 이동 — main 병합)
- 한 것: `SoldierGame`(FlameGame + RiverpodGameMixin), 하드코딩 테스트 맵(1400², 70px 격자, 외곽·높은 벽, 낮은 상자는 지금은 벽처럼), 플레이어(반경 16, 총구 표시), 회전 시점(정면 = 화면 위, 플레이어 50%/66%), 떠다니는 조이스틱(왼쪽) + 드래그 회전(오른쪽, 감도), 웹 디버그 키 WASD/←→, 축 분리 벽 충돌, 나침반 HUD. 이동 계산은 `rules/movement.dart` 순수 함수. 조작 수치는 `balance.dart`. 테스트 53개 통과.
- 다음: 점프·앉기(자세) 또는 달리기(조이스틱 바깥 원 80px).
- 추가: 안드로이드 빌드 실패 수정(`kotlin.incremental=false`, 프로젝트 D: / Pub 캐시 C: 드라이브 차이), 가로 화면 고정(`sensorLandscape`). 에뮬레이터·크롬 동작 확인됨(사용자). 나침반에 항상 똑바로 선 N 표시.
- 막힌 것: 없음. ←→ 키 회전 속도 3.0 rad/s는 decisions에 없는 디버그용 제안값.

## 2026-10-02 (rules 계층)
- 한 것: `lib/rules/` TDD로 작성 — `balance.dart`(자세, 미스/크리, 등급·강화, 무기 11종, 캐릭터 4종), `combat.dart`(판정 함수), `character.dart`(강화 능력치). 테스트 34개 통과. 성장 격차 불변식에서 기본 병사가 2.33발로 초과 → 강화당 체력 +3 → +2로 결정(1.96발), decisions 5·8장 반영. 권총 크리 배율 ×2 확정. main에 squash 병합.
- 성장 격차(표준형 라이플, +5 vs 신규): 기본 병사 1.96 / 저격수형 1.17 / 정찰형 1.54 / 강습형 1.37
- 다음: 사격 구현 때 무기 사거리·탄창·재장전 추가(decisions 6장 참고 기준값), 게임 화면(조작·자세) 시작
- 막힌 것: 없음

## 2026-10-02 (프로젝트 세팅)
- 한 것: `flutter create`(android, web), 패키지 추가(flame 1.38, flame_tiled 3.1, flutter_riverpod 3.4, flame_riverpod 5.5, shared_preferences 2.5 / dev: flame_test 2.3), `analysis_options.yaml` 강화, `lib/` 빈 폴더 구조, Dart 파일 자동 포맷 훅(`.claude/hooks/format_dart.sh`, Windows 동작 확인), `.gitignore`에 비밀값 항목 추가, git 첫 커밋
- 다음: `rules/` 테스트부터 (자세·명중/미스/크리티컬 수치, `balance.dart`)
- 막힌 것: 없음 (flutter doctor의 Visual Studio 누락은 Windows 데스크톱용이라 무관)

## 2026-10-02
- 한 것: 기획 결정 정리(`docs/decisions.md`), `CLAUDE.md` 작성, CI 워크플로 초안
- 다음: Flutter 프로젝트 생성, 패키지 세팅, 포맷 훅, `rules/` 테스트부터 시작
- 막힌 것: 없음
