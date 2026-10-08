import 'package:flutter_test/flutter_test.dart';
import 'package:topsoldier/data/models/holiday.dart';
import 'package:topsoldier/data/repositories/event_repository.dart';
import 'package:topsoldier/data/services/holiday_service.dart';

/// getRestDeInfo 응답 모양(items.item: 배열 / 객체 / 없음은 빈 문자열).
Map<String, Object?> response(Object items) => {
  'response': {
    'header': {'resultCode': '00', 'resultMsg': 'NORMAL SERVICE.'},
    'body': {'items': items, 'numOfRows': 50, 'pageNo': 1, 'totalCount': 0},
  },
};

const hangul = {
  'dateKind': '01',
  'dateName': '한글날',
  'isHoliday': 'Y',
  'locdate': 20261009,
  'seq': 1,
};
const chuseok = {
  'dateKind': '01',
  'dateName': '추석',
  'isHoliday': 'Y',
  'locdate': 20260925,
  'seq': 1,
};

class FakeHolidayService implements HolidayService {
  FakeHolidayService(this.answer);
  final Object? Function() answer;
  final asked = <(int, int)>[];

  @override
  Future<Object?> fetchMonth(int year, int month) async {
    asked.add((year, month));
    return answer();
  }
}

void main() {
  group('Holiday.listFromJson', () {
    test('several items (array)', () {
      final list = Holiday.listFromJson(
        response({
          'item': [chuseok, hangul],
        }),
      );
      expect(list.map((h) => h.name), ['추석', '한글날']);
      expect(list.last.date, DateTime(2026, 10, 9));
    });

    test('one item comes as an object, not an array', () {
      final list = Holiday.listFromJson(response({'item': hangul}));
      expect(list.single.name, '한글날');
    });

    test('no holidays: items is an empty string', () {
      expect(Holiday.listFromJson(response('')), isEmpty);
    });

    test('isHoliday N (not a day off) is skipped', () {
      final list = Holiday.listFromJson(
        response({
          'item': {...hangul, 'isHoliday': 'N'},
        }),
      );
      expect(list, isEmpty);
    });
  });

  group('EventRepository.todayHoliday', () {
    test('today is a holiday → that holiday, asks for this month', () async {
      final service = FakeHolidayService(
        () => response({
          'item': [hangul],
        }),
      );
      final h = await EventRepository(service)
          .todayHoliday(DateTime(2026, 10, 9, 14, 30));
      expect(h?.name, '한글날');
      expect(service.asked, [(2026, 10)]);
    });

    test('another day of the month → no event', () async {
      final repo = EventRepository(
        FakeHolidayService(() => response({'item': hangul})),
      );
      expect(await repo.todayHoliday(DateTime(2026, 10, 7)), isNull);
    });

    test('failure (no key, network, web CORS, XML error) → no event', () async {
      final repo = EventRepository(
        FakeHolidayService(() => throw StateError('no key')),
      );
      expect(await repo.todayHoliday(DateTime(2026, 10, 9)), isNull);
    });

    test('empty key with the real service → no event, no request', () async {
      expect(
        await EventRepository(HttpHolidayService(''))
            .todayHoliday(DateTime(2026, 10, 9)),
        isNull,
      );
    });
  });
}
