import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/holiday.dart';
import '../services/holiday_service.dart';

final eventRepositoryProvider = Provider(
  (ref) => EventRepository(
    HttpHolidayService(const String.fromEnvironment('HOLIDAY_API_KEY')),
  ),
);

/// 공휴일 이벤트(decisions 1장: 공휴일에 매치 보상 2배).
class EventRepository {
  EventRepository(this._holidays);

  final HolidayService _holidays;

  /// 오늘이 공휴일이면 그 공휴일. 키 없음·네트워크 실패·웹 CORS 실패는 모두 "이벤트 없음".
  Future<Holiday?> todayHoliday(DateTime now) async {
    try {
      final list = Holiday.listFromJson(
        await _holidays.fetchMonth(now.year, now.month),
      );
      for (final h in list) {
        if (h.date.year == now.year &&
            h.date.month == now.month &&
            h.date.day == now.day) {
          return h;
        }
      }
      return null;
    } catch (_) {
      return null;
    }
  }
}
