import 'package:package_info_plus/package_info_plus.dart';

/// 설치된 앱 정보(pubspec의 version).
class AppInfoService {
  /// "0.1.1+2" 처럼 버전 + 빌드 번호.
  Future<String> version() async {
    final info = await PackageInfo.fromPlatform();
    return '${info.version}+${info.buildNumber}';
  }
}
