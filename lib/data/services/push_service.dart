import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

/// FCM 토픽 푸시. 보내는 쪽은 Firebase 콘솔 예약 발송(docs/push.md).
abstract class PushService {
  /// 알림 권한을 묻고 이벤트 토픽을 구독한다.
  Future<void> subscribeEvents();
}

class FirebasePushService implements PushService {
  /// 공휴일 이벤트 시작 알림 토픽.
  static const eventTopic = 'holiday_event';

  @override
  Future<void> subscribeEvents() async {
    // 웹은 테스트용 클라이언트라 푸시를 쓰지 않는다(서비스 워커·VAPID 키 필요).
    if (kIsWeb) return;
    final fcm = FirebaseMessaging.instance;
    await fcm.requestPermission(); // Android 13+ 알림 권한
    await fcm.subscribeToTopic(eventTopic);
  }
}
