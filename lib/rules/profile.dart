import 'balance.dart';

/// [level]에서 다음 레벨까지 필요한 경험치.
int expToNext(int level) => levelExpBase + levelExpStep * (level - 1);

/// [exp]는 지금 레벨 안에서 쌓인 경험치. 여러 레벨을 한 번에 넘을 수 있다.
({int level, int exp}) addExp({
  required int level,
  required int exp,
  required int gained,
}) {
  var l = level;
  var e = exp + gained;
  while (e >= expToNext(l)) {
    e -= expToNext(l);
    l++;
  }
  return (level: l, exp: e);
}

final _nickname = RegExp(r'^[가-힣a-zA-Z0-9]+$');

/// 닉네임이 안 되면 이유, 되면 null.
String? nicknameError(String name) {
  if (name.length < nicknameMin || name.length > nicknameMax) {
    return '$nicknameMin~$nicknameMax자로 입력하세요.';
  }
  if (!_nickname.hasMatch(name)) return '한글, 영문, 숫자만 쓸 수 있습니다.';
  return null;
}

/// 승률 0~1. 0판이면 0.
double winRate({required int wins, required int matches}) =>
    matches == 0 ? 0 : wins / matches;

/// 킬 ÷ 데스. 0데스면 킬 수 그대로.
double kdRatio({required int kills, required int deaths}) =>
    deaths == 0 ? kills.toDouble() : kills / deaths;
