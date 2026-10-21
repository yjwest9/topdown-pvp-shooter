#!/bin/bash
# 로컬 Firebase 에뮬레이터(auth 9099, database 9000)를 켠 뒤 `bash tool/rules_check.sh`.
# database.rules.json 허용/거부 확인. 마지막에 이 스크립트가 만든 테스트 유저만 지운다.
NS=topsoldier-default-rtdb
DB=http://localhost:9000
tok() { curl -s -X POST "http://localhost:9099/identitytoolkit.googleapis.com/v1/accounts:signUp?key=x" -H 'Content-Type: application/json' -d '{"returnSecureToken":true}' | sed -E 's/.*"idToken": *"([^"]+)".*/\1/;s/.*"localId": *"([^"]+)".*//' ; }
uid() { curl -s -X POST "http://localhost:9099/identitytoolkit.googleapis.com/v1/accounts:lookup?key=x" -H 'Content-Type: application/json' -d "{\"idToken\":\"$1\"}" | grep -o '"localId": *"[^"]*"' | head -1 | sed -E 's/.*"([^"]+)"$/\1/'; }
TA=$(tok); TB=$(tok); TC=$(tok); A=$(uid $TA); B=$(uid $TB); C=$(uid $TC)
admin() { curl -s -o /dev/null -X "$1" "$DB/$2.json?ns=$NS" -H "Authorization: Bearer owner" ${3:+-d "$3"}; }
req() { code=$(curl -s -o /dev/null -w '%{http_code}' -X "$2" "$DB/$3.json?ns=$NS&auth=$1" ${4:+-d "$4"}); [ "$code" = 200 ] && echo allow || echo deny; }
check() { got=$1; want=$2; name=$3; [ "$got" = "$want" ] && echo "OK   $name ($got)" || echo "FAIL $name (got $got, want $want)"; }
W=matchmaking/1v1/waiting
NOW=$(($(date +%s)*1000)); OLD=$((NOW-20000))
slot() { echo "{\"uid\":\"$1\",\"roomId\":\"r1\",\"name\":\"n\",\"t\":$2${3:+,\"takenBy\":\"$3\"}}"; }

admin DELETE $W
check $(req $TA PUT $W "$(slot $A $NOW)") allow "빈 자리에 앉기"
check $(req $TB PUT $W "$(slot $B $NOW)") deny  "남의 살아 있는 자리에 앉기"
check $(req $TA PUT $W "$(slot $A $((NOW+1000)))") allow "내 자리 t 갱신"
check $(req $TA PUT $W "$(slot $A $((NOW+60000)))") deny  "t를 먼 미래로"
check $(req $TC PUT $W "$(slot $A $((NOW+1000)) $B)") deny  "takenBy에 남의 uid"
check $(req $TB DELETE $W) deny "남의 자리 삭제"
check $(req $TB PUT $W "$(slot $A $((NOW+1000)) $B)") allow "takenBy = 나(take)"
check $(req $TC PUT $W "$(slot $A $((NOW+1000)) $C)") deny  "이미 잡힌 자리 다시 take"
check $(req $TA PUT $W "$(slot $A $((NOW+2000)))") allow "방장이 자기 자리를 새로 쓰기(takenBy 빠짐, 이전 실행의 자리 재사용)"
check $(req $TA DELETE $W) allow "내 자리 삭제"
admin PUT $W "$(slot $A $OLD)"
check $(req $TB PUT $W "$(slot $B $NOW $C)") deny  "오래된 자리에 takenBy 달고 앉기"
check $(req $TB PUT $W "$(slot $B $NOW)") allow "오래된(15초 넘은) 자리에 앉기"
admin PUT rooms/q1 "{\"meta\":{\"hostUid\":\"$A\",\"status\":\"ended\"},\"players\":{\"$A\":{\"connected\":false},\"$B\":{\"connected\":false}},\"hp\":{\"$A\":{\"value\":100}}}"
check $(req $TC DELETE rooms/q1) deny  "참가자 아닌 사람이 방 삭제"
check $(req $TB DELETE rooms/q1/hp/$A) deny "참가자가 남의 체력 노드 삭제"
check $(req $TB PUT rooms/q1 '{"meta":{"hostUid":"x"}}') deny "참가자가 방 통째로 덮어쓰기"
check $(req $TB DELETE rooms/q1) allow "참가자가 방 삭제"
admin DELETE $W
P='{"nickname":"솔저","level":1,"exp":0,"gold":0,"diamond":0}'
check $(req $TA PUT users/$A "$P") allow "내 프로필 만들기"
check $(req $TB GET users/$A) deny "남의 프로필 읽기"
check $(req $TA GET users/$A) allow "내 프로필 읽기"
check $(req $TB PATCH users/$A '{"gold":999}') deny "남의 골드 바꾸기"
check $(req $TA PATCH users/$A '{"gold":5000,"exp":30}') allow "내 골드·경험치 더하기"
check $(req $TA PATCH users/$A '{"gold":-1}') deny "골드 음수"
check $(req $TA PATCH users/$A '{"diamond":"many"}') deny "다이아에 글자"
check $(req $TA PATCH users/$A '{"level":0}') deny "레벨 0"
check $(req $TA PATCH users/$A '{"nickname":"a"}') deny "닉네임 1자"
W1='{"weaponId":"sniper_bolt","grade":"E","level":0,"acquiredAt":1}'
check $(req $TA PUT users/$A/weapons/w1 "$W1") allow "내 무기 추가"
check $(req $TB PUT users/$A/weapons/w2 "$W1") deny "남의 weapons 쓰기"
check $(req $TA PUT users/$A/weapons/w3 '{"weaponId":"ak47","grade":"E","level":0}') deny "없는 weaponId"
check $(req $TA PUT users/$A/weapons/w4 '{"weaponId":"pistol","grade":"D","level":0}') deny "새 무기를 D등급으로 만들기"
check $(req $TA PUT users/$A/weapons/w5 '{"weaponId":"pistol","grade":"E","level":9}') deny "강화 9"
check $(req $TA PATCH users/$A/loadout '{"primary":"w1"}') allow "보유 무기 장착"
check $(req $TA PATCH users/$A/loadout '{"primary":"nope"}') deny "없는 개체 장착"
check $(req $TB PATCH users/$A/loadout '{"primary":"w1"}') deny "남의 로드아웃"
check $(req $TA PATCH users/$A "{\"gold\":0,\"weapons/w6\":$W1}") allow "다중 경로(골드+무기) 한 번에"
check $(req $TA PATCH users/$A/weapons/w1 '{"level":1}') allow "강화 +1"
check $(req $TA PATCH users/$A/weapons/w1 '{"level":3}') deny "강화 +2 점프(1 -> 3)"
check $(req $TA PATCH users/$A/weapons/w1 '{"level":0}') deny "강화 단계 내리기"
check $(req $TA PATCH users/$A/weapons/w1 '{"level":1}') allow "단계 그대로(골드만 빠지는 실패)"
check $(req $TB PATCH users/$A/weapons/w1 '{"level":2}') deny "남의 무기 강화"
check $(req $TA PUT users/$A/weapons/w9 '{"weaponId":"pistol","grade":"E","level":3}') deny "새 무기를 +3으로 만들기"
check $(req $TA PATCH users/$A/weapons/w1 '{"weaponId":"pistol"}') deny "보유 무기 종류 바꾸기"
M5='{"weaponId":"rifle_standard","grade":"E","level":5,"acquiredAt":1}'
admin PUT users/$A/weapons/m1 "$M5"
admin PUT users/$A/weapons/m2 '{"weaponId":"rifle_rapid","grade":"E","level":4,"acquiredAt":1}'
admin PUT users/$A/weapons/m3 "$M5"
check $(req $TA PATCH users/$A/weapons/m2 '{"grade":"D","level":0}') deny "합성: E+4 -> D+0"
check $(req $TA PATCH users/$A/weapons/m1 '{"grade":"D","level":1}') deny "합성: E+5 -> D+1"
check $(req $TA PATCH users/$A/weapons/m1 '{"grade":"D"}') deny "합성: E+5 -> D인데 단계 5 그대로"
check $(req $TA PATCH users/$A/weapons/m1 '{"grade":"D","level":0,"weaponId":"pistol"}') deny "합성하면서 종류 바꾸기"
check $(req $TA PATCH users/$A/weapons/m1 '{"grade":"X","level":0}') deny "알 수 없는 등급"
check $(req $TB PATCH users/$A/weapons/m1 '{"grade":"D","level":0}') deny "남의 무기 합성"
check $(req $TB DELETE users/$A/weapons/m3) deny "남의 무기 삭제"
check $(req $TA PATCH users/$A/weapons/m1 '{"grade":"D","level":0}') allow "합성: E+5 -> D+0"
check $(req $TA PATCH users/$A/weapons/m1 '{"grade":"E","level":0}') deny "D -> E"
check $(req $TA PATCH users/$A/weapons/m1 '{"grade":"E","level":5}') deny "D+0 -> E+5"
check $(req $TA PATCH users/$A/weapons/m1 '{"level":1}') allow "D+0 -> D+1 강화"
check $(req $TA PATCH users/$A/weapons/m1 '{"level":3}') deny "D 강화 +2 점프"
check $(req $TA DELETE users/$A/weapons/m3) allow "재료 무기 삭제"
admin PUT users/$A/weapons/m1 "$M5"
admin PUT users/$A/weapons/m3 "$M5"
check $(req $TA PATCH users/$A '{"gold":0,"weapons/m1/grade":"D","weapons/m1/level":0,"weapons/m3":null}') allow "합성 한 번에(골드 차감 + 기준 D+0 + 재료 삭제)"
admin DELETE users/$A/weapons/m1
admin DELETE users/$A/weapons/m2
TS='{".sv":"timestamp"}'
check $(req $TA PATCH users/$A "{\"lastAdAt\":$TS}") allow "lastAdAt 없을 때 서버 시간으로 쓰기"
check $(req $TA PATCH users/$A "{\"lastAdAt\":$TS}") deny "1시간 안에 다시 쓰기"
check $(req $TA PATCH users/$A '{"lastAdAt":0}') deny "서버 시간이 아닌 숫자(0)로 쓰기"
check $(req $TB PATCH users/$A "{\"lastAdAt\":$TS}") deny "남의 lastAdAt 쓰기"
cur=$(curl -s "$DB/users/$A/lastAdAt.json?ns=$NS" -H "Authorization: Bearer owner")
check $(req $TA PATCH users/$A "{\"diamond\":100,\"lastAdAt\":$cur}") allow "lastAdAt 그대로 두고 다른 값 쓰기(환전 트랜잭션)"
check $(req $TA PUT users/$A "$(curl -s "$DB/users/$A.json?ns=$NS" -H "Authorization: Bearer owner")") allow "users 통째로 다시 쓰기, lastAdAt 그대로"
admin PUT users/$A/lastAdAt "$(( $(date +%s)*1000 - 3600001 ))"
check $(req $TA PATCH users/$A "{\"gold\":{\".sv\":{\"increment\":10000}},\"lastAdAt\":$TS}") allow "1시간 넘게 지난 뒤 다시(골드 +10,000과 한 번에)"
AM='{"matchId":"r1-9000","startedAt":'"$TS"'}'
check $(req $TA PUT users/$A/activeMatch "$AM") allow "빠른 대전 시작 표시(activeMatch, 서버 시간)"
check $(req $TB PUT users/$A/activeMatch "$AM") deny "남의 activeMatch 쓰기"
check $(req $TA PUT users/$A/activeMatch '{"matchId":"r1-9000","startedAt":0}') deny "activeMatch startedAt이 서버 시간이 아님"
check $(req $TA PUT users/$A/activeMatch '{"matchId":5,"startedAt":'"$TS"'}') deny "activeMatch matchId가 숫자"
check $(req $TA PUT users/$A/activeMatch '{"startedAt":'"$TS"'}') deny "activeMatch matchId 없음"
check $(req $TA PUT users/$A/activeMatch '{"matchId":"r1-9000","startedAt":'"$TS"',"x":1}') deny "activeMatch에 다른 항목"
check $(req $TA PUT users/$A "$(curl -s "$DB/users/$A.json?ns=$NS" -H "Authorization: Bearer owner")") allow "activeMatch 그대로 두고 users 통째로 쓰기(결과 저장 트랜잭션)"
check $(req $TB DELETE users/$A/activeMatch) deny "남의 activeMatch 지우기"
check $(req $TA DELETE users/$A/activeMatch) allow "activeMatch 지우기"
admin PUT rooms/q2 "{\"meta\":{\"hostUid\":\"$A\",\"status\":\"playing\"},\"players\":{\"$A\":{\"connected\":true}}}"
check $(req $TA PUT rooms/q2/hp/$A '{"value":110,"protectedUntil":0}') allow "hp 자기 복구 110(기본 병사 +5)"
check $(req $TA PUT rooms/q2/hp/$A '{"value":111,"protectedUntil":0}') deny "hp 자기 복구 111"
check $(req $TA PUT rooms/q2/hp/$A '{"value":89,"protectedUntil":0}') deny "hp 자기 복구 89"
check $(req $TA PUT rooms/q2/hp/$A '{"value":90,"protectedUntil":0}') allow "hp 자기 복구 90(정찰병)"
admin DELETE rooms/q2
check $(req $TA PUT users/$A/characters/scout '{"level":0}') allow "새 캐릭터 level 0"
check $(req $TA PUT users/$A/characters/marksman '{"level":3}') deny "새 캐릭터를 +3으로"
check $(req $TA PATCH users/$A/characters/scout '{"level":2}') deny "캐릭터 강화 +2 점프(0 -> 2)"
check $(req $TA PATCH users/$A/characters/scout '{"level":1}') allow "캐릭터 강화 +1"
check $(req $TA PUT users/$A/characters/ninja '{"level":0}') deny "모르는 캐릭터 id"
check $(req $TB PUT users/$A/characters/assault '{"level":0}') deny "남의 캐릭터 쓰기"
check $(req $TA PATCH users/$A '{"equippedCharacter":"basic"}') allow "장착 'basic'(보유 기록 없어도)"
check $(req $TA PATCH users/$A '{"equippedCharacter":"assault"}') deny "미보유 캐릭터 장착"
check $(req $TA PATCH users/$A '{"equippedCharacter":"scout"}') allow "보유 캐릭터 장착"
# 친선전 2대2: 대기실 팀 이동·자리 바꾸기(decisions 12장). 새 필드(swapTo·swapAt·swapAccepted·swapDeclined)는 본인 노드 안에서만.
admin PUT rooms/q3 "{\"meta\":{\"hostUid\":\"$A\",\"status\":\"waiting\",\"teamSize\":2},\"players\":{\"$A\":{\"connected\":true,\"team\":\"A\"}}}"
check $(req $TA PATCH rooms/q3/meta '{"teamSize":2}') allow "방장이 meta teamSize 쓰기"
check $(req $TB PATCH rooms/q3/meta '{"teamSize":1}') deny "참가자가 meta teamSize 바꾸기"
check $(req $TB PUT rooms/q3/players/$B '{"name":"b","connected":true,"team":"B"}') allow "입장(내 노드, 팀 배정)"
check $(req $TA PATCH rooms/q3/players/$A '{"swapTo":"'"$B"'","swapAt":'"$TS"'}') allow "내 노드에 자리 바꾸기 요청(swapTo·swapAt)"
check $(req $TB PATCH rooms/q3/players/$A '{"swapTo":"x"}') deny "남의 노드에 자리 바꾸기 요청"
check $(req $TB PATCH rooms/q3/players/$B '{"team":"A","swapAccepted":"'"$A"'"}') allow "내 노드에 수락(내 팀 변경 + swapAccepted)"
check $(req $TB PATCH rooms/q3/players/$B '{"swapDeclined":"'"$A"'"}') allow "내 노드에 거절(swapDeclined)"
check $(req $TA PATCH rooms/q3/players/$B '{"team":"B"}') deny "남의 팀 바꾸기"
check $(req $TA PATCH rooms/q3/players/$A '{"team":"B","swapTo":null,"swapAt":null}') allow "요청자가 내 팀 변경 + 요청 정리"
check $(req $TB PATCH rooms/q3/players/$B '{"swapAccepted":null,"swapDeclined":null}') allow "수락·거절 표시 정리"
check $(req $TC PATCH rooms/q3/players/$A '{"team":"B"}') deny "방 밖 사람이 남의 팀 바꾸기"
admin DELETE rooms/q3
# 마무리 담당(방장이 나갔을 때 남은 사람)이 결과를 기록한다: 방 참가자는 playing → ended만.
admin PUT rooms/q4 "{\"meta\":{\"hostUid\":\"$A\",\"status\":\"playing\",\"teamSize\":2},\"players\":{\"$A\":{\"connected\":false,\"team\":\"A\"},\"$B\":{\"connected\":true,\"team\":\"B\"}}}"
check $(req $TC PATCH rooms/q4/meta '{"status":"ended","winner":"B"}') deny "방 밖 사람이 결과 기록"
check $(req $TB PATCH rooms/q4/meta '{"status":"waiting"}') deny "참가자가 상태를 playing에서 되돌리기"
check $(req $TB PATCH rooms/q4/meta '{"hostUid":"'"$B"'"}') deny "참가자가 방장 바꾸기"
check $(req $TB PATCH rooms/q4/meta '{"teamSize":1}') deny "참가자가 teamSize 바꾸기(playing 중)"
check $(req $TB PATCH rooms/q4/meta '{"status":"ended","winner":"B"}') allow "방 참가자가 playing → ended 결과 기록"
admin PUT rooms/q4/meta "{\"hostUid\":\"$A\",\"status\":\"waiting\"}"
check $(req $TB PATCH rooms/q4/meta '{"status":"ended","winner":"B"}') deny "대기 중(waiting)에는 참가자가 끝내기 불가"
check $(req $TA PATCH rooms/q4/meta '{"status":"playing"}') allow "방장은 그대로 시작"
admin DELETE rooms/q4
for u in $A $B $C; do admin DELETE users/$u; done

