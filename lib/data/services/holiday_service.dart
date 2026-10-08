import 'dart:convert';

import 'package:http/http.dart' as http;

abstract class HolidayService {
  /// 그 달의 공휴일 응답(JSON 그대로).
  Future<Object?> fetchMonth(int year, int month);
}

/// 한국천문연구원 특일정보 API(공공데이터포털). 키는 --dart-define(HOLIDAY_API_KEY).
class HttpHolidayService implements HolidayService {
  HttpHolidayService(this.apiKey);

  /// 일반 인증키. 포털의 Encoding·Decoding 키 어느 쪽이든 된다
  /// (한 번 디코딩한 뒤 쿼리에 넣을 때 다시 인코딩된다).
  final String apiKey;

  @override
  Future<Object?> fetchMonth(int year, int month) async {
    if (apiKey.isEmpty) throw StateError('HOLIDAY_API_KEY가 없습니다.');
    final uri = Uri.https(
      'apis.data.go.kr',
      '/B090041/openapi/service/SpcdeInfoService/getRestDeInfo',
      {
        'ServiceKey': Uri.decodeComponent(apiKey),
        'solYear': '$year',
        'solMonth': month.toString().padLeft(2, '0'),
        '_type': 'json',
        'numOfRows': '50',
      },
    );
    final res = await http.get(uri).timeout(const Duration(seconds: 5));
    if (res.statusCode != 200) throw http.ClientException('${res.statusCode}');
    // 키 오류 등은 JSON이 아니라 XML로 온다 → 여기서 FormatException.
    return jsonDecode(utf8.decode(res.bodyBytes));
  }
}
