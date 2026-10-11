import 'package:shared_preferences/shared_preferences.dart';

/// 기기 안에 저장하는 작은 설정값. 서버로 보내지 않는다.
class PrefsService {
  Future<bool?> getBool(String key) async =>
      (await SharedPreferences.getInstance()).getBool(key);

  Future<void> setBool(String key, bool value) async =>
      (await SharedPreferences.getInstance()).setBool(key, value);
}
