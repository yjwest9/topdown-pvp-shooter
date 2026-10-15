/// 1234567 → "1,234,567"
String commas(int n) =>
    n.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');

/// 연결 실패는 영어 원문 대신 이 한 줄만 보여 준다(원문은 `debugPrint`로 로그에만).
const connectionErrorText = '인터넷 연결을 확인해 주세요';
