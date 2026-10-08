/// 특일정보 API(한국천문연구원)의 공휴일 하루.
class Holiday {
  const Holiday({required this.date, required this.name});

  /// 날짜만(시각 0시, 로컬).
  final DateTime date;
  final String name;

  /// `getRestDeInfo` JSON 응답 → 공휴일 목록.
  /// items.item은 여러 개면 배열, 한 개면 객체, 없으면 items가 빈 문자열이다.
  static List<Holiday> listFromJson(Object? json) {
    final body = ((json! as Map)['response'] as Map)['body'] as Map;
    final items = body['items'];
    if (items is! Map) return const [];
    final item = items['item'];
    final list = item is List ? item : [item];
    return [
      for (final e in list.cast<Map<Object?, Object?>>())
        if (e['isHoliday'] == 'Y') _fromItem(e),
    ];
  }

  static Holiday _fromItem(Map<Object?, Object?> e) {
    final d = e['locdate'].toString(); // 20261009
    return Holiday(
      date: DateTime(
        int.parse(d.substring(0, 4)),
        int.parse(d.substring(4, 6)),
        int.parse(d.substring(6, 8)),
      ),
      name: e['dateName'] as String,
    );
  }
}
