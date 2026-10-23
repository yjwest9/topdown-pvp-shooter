import 'package:flutter/widgets.dart';

/// 계정을 바꾼 뒤 앱 상태(Provider 전부)를 처음부터 다시 만든다.
class RestartScope extends StatefulWidget {
  const RestartScope({super.key, required this.child});

  final Widget child;

  /// [RestartScope] 안이 아니면(위젯 테스트) 아무 일도 안 한다.
  static void restart(BuildContext context) =>
      context.findAncestorStateOfType<_RestartScopeState>()?.restart();

  @override
  State<RestartScope> createState() => _RestartScopeState();
}

class _RestartScopeState extends State<RestartScope> {
  Key _key = UniqueKey();

  void restart() => setState(() => _key = UniqueKey());

  @override
  Widget build(BuildContext context) =>
      KeyedSubtree(key: _key, child: widget.child);
}
