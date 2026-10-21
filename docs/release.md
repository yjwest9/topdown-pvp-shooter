# 릴리스 (Google Play)

패키지: `com.yjseo.topsoldier` (업로드 후 변경 불가). 앱 이름: TOP SOLDIER.

## 1. 버전 올리기

`pubspec.yaml`의 `version: 이름+빌드번호`.

```yaml
version: 0.1.0+1   # 첫 업로드
version: 0.1.1+2   # 다음 업로드
```

- **빌드 번호(`+` 뒤)는 업로드할 때마다 반드시 1 이상 올린다.** Play Console은 같은 번호를 다시 받지 않는다.
- 이름(`0.1.1`)은 사람이 보는 버전. 작은 수정은 마지막 자리, 기능 묶음은 가운데 자리.
- 올린 빌드에는 git 태그: `git tag v0.1.1` (main에서, 사용자 확인 후).

## 2. 빌드

```bash
dart format .
flutter analyze
flutter test
flutter build appbundle --release --dart-define-from-file=.env.local
```

`.env.local`(커밋 안 됨)에 `HOLIDAY_API_KEY`가 있어야 공휴일 이벤트가 동작한다(docs/push.md). 빠지면 이벤트만 꺼진다.

결과: `build/app/outputs/bundle/release/app-release.aab` → Play Console에 업로드.

- `android/key.properties`가 없으면 경고만 내고 **서명 안 된** .aab가 나온다(CI용). 이건 업로드할 수 없다.
- 서명 확인: `keytool -printcert -jarfile build/app/outputs/bundle/release/app-release.aab`
  ("Not a signed jar file"이면 서명 안 됨).

## 3. 업로드 키

| 파일 | 위치 | 커밋 |
|---|---|---|
| 키 저장소 | `D:\keys\topsoldier-upload.jks` (프로젝트 밖) | 절대 안 함 |
| 키 설정 | `android/key.properties` (비밀번호 포함) | 안 함 (.gitignore) |
| 형식 예시 | `android/key.properties.example` | 함 (값 비움) |

`key.properties` 만들기: example을 복사해서 채운다.

```properties
storePassword=<저장소 비밀번호>
keyPassword=<키 비밀번호>
keyAlias=upload
storeFile=D:/keys/topsoldier-upload.jks
```

키 처음 만들기 (한 번만):

```bash
keytool -genkey -v -keystore D:\keys\topsoldier-upload.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

### 백업 주의

- **.jks 파일과 비밀번호를 잃어버리면 업로드를 못 한다.** Play 앱 서명을 쓰면 Google에 업로드 키 재설정을 요청할 수 있지만 며칠 걸린다.
- .jks는 프로젝트 밖 두 군데 이상에 백업(예: USB, 개인 클라우드). 비밀번호는 비밀번호 관리자에.
- .jks, key.properties, 비밀번호를 git·채팅·스크린샷에 올리지 않는다.
- 첫 업로드 때 Play Console에서 **Play 앱 서명**을 켠다(기본값). 실제 앱 서명 키는 Google이 보관하고, 우리 키는 업로드용이 된다.

## 4. 릴리스와 실서버 DB 규칙

앱이 쓰는 데이터가 규칙에 막히면 새 앱이 실서버에서 동작하지 않는다. 규칙이 바뀐 릴리스는 **앱 업로드 전에 규칙을 먼저 배포**한다(옛 앱도 새 규칙에서 동작해야 하므로 규칙은 넓히는 방향으로만).

```bash
firebase database:get /.settings/rules > live.json   # 실서버 규칙 받기, database.rules.json과 비교(주석 제외)
bash tool/rules_check.sh                              # 로컬 에뮬레이터(auth, database)를 켠 뒤. 전부 OK여야 한다
firebase deploy --only database                       # 배포
firebase database:get /.settings/rules                # 다시 받아 로컬과 같은지 확인
```

- 에뮬레이터가 이전 실행에서 안 꺼진 채 남아 있으면(`port taken`) 대기석 항목이 실패한다. 남은 `java`·`node` 프로세스를 끄고 다시 켠다.

| 릴리스 | 규칙 배포 | 내용 |
|---|---|---|
| 0.1.7+9 (2026-10-21) | **포함** | 무기 합성: 보유 무기 grade에 `D` 허용, E+5 → D+0 한 가지 변경만 허용(그 밖의 등급 변경은 거부), 새 무기는 E+0만. 배포 전 실서버와의 차이는 이것 하나뿐이었고 배포 뒤 실서버 규칙 = 로컬(rules_check 75개 OK) |
| 0.1.5, 0.1.6 | 없음 | 실서버 규칙과 로컬이 같은 것만 확인하고 배포 안 함 |
