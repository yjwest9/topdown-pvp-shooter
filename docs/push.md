# 공휴일 이벤트 + 푸시 (Open API)

decisions 1장: 한국천문연구원 특일정보 API로 오늘이 공휴일인지 확인 → 매치 보상 2배 이벤트. 이벤트 시작은 FCM 푸시로 알린다.

## 1. API 키 (처음 한 번)

1. [공공데이터포털](https://www.data.go.kr)에서 "한국천문연구원_특일 정보" 활용신청 → 마이페이지에서 **일반 인증키** 복사 (Encoding·Decoding 어느 쪽이든 됨)
2. 프로젝트 루트 `.env.local`에 넣는다. 이 파일은 커밋되지 않는다(`.gitignore`의 `.env.*`).
   ```
   HOLIDAY_API_KEY=여기에_키
   ```
3. 실행할 때 `--dart-define-from-file=.env.local`을 붙인다.
   ```bash
   flutter run -d emulator-5554 --dart-define=USE_EMULATOR=true --dart-define-from-file=.env.local
   flutter build appbundle --dart-define-from-file=.env.local   # Play 업로드용
   ```
   키 없이 실행하면 이벤트가 없는 것으로 처리된다(오류 아님). 웹(크롬)은 API가 CORS를 허용하지 않아 실패 → 역시 이벤트 없음.

## 2. 앱 동작

- 앱을 켜면 이번 달 공휴일을 한 번 받아 와서 오늘이 공휴일이면 로비에 "오늘은 한글날! 매치 보상 2배 이벤트", 결과 화면에 "이벤트: 한글날 보상 ×2"를 보여 준다.
- 골드 보상은 아직 없다(decisions 15장 3번). 생기면 `holidayRewardMultiplier`(balance.dart)를 곱한다.
- 안드로이드는 시작할 때 알림 권한을 묻고 FCM 토픽 `holiday_event`를 구독한다. 웹은 구독하지 않는다.

## 3. 이벤트 시작 푸시 보내기 (Firebase 콘솔 예약 발송)

Spark 요금제라 서버(Cloud Functions)가 자동으로 보내지 않는다. 공휴일마다 콘솔에서 예약한다.

1. Firebase 콘솔 → 프로젝트 `topsoldier` → **Messaging** → **새 캠페인** → **Firebase 알림 메시지**
2. 제목 `오늘은 한글날!`, 내용 `매치 보상 2배 이벤트가 시작됐어요.`
3. 타겟: **주제(Topic)** → `holiday_event`
4. 예약: 맞춤 일정 → 2026-10-09 09:00, 시간대 Asia/Seoul
5. 검토 → 게시

### 바로 시험하기

같은 순서에서 4번을 "지금"으로 보낸다. 앱을 **백그라운드**로 보내 두면(홈 버튼) 알림이 상단에 뜬다. 앱이 앞에 떠 있을 때는 FCM이 알림을 표시하지 않는다(지금은 앞 화면 알림 처리 없음).

- 토픽 구독은 앱 설치 후 처음 실행할 때 이뤄지고, 서버 반영에 몇 분 걸릴 수 있다.
- 안드로이드 에뮬레이터는 Google Play가 들어간 이미지여야 FCM을 받는다.

## 4. 플레이스토어에 올리기 전에

푸시(FCM)를 넣은 빌드를 올릴 때는 데이터 보안 설문(기기 ID: FCM 토큰)과 개인정보처리방침(3장 외부 서비스에 Firebase Cloud Messaging)을 먼저 고친다.
