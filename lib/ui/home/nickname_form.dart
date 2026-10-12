import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../rules/balance.dart';
import 'home_view_model.dart';

/// 닉네임 입력. [first]면 첫 실행(프로필 만들기), 아니면 바꾸기(대화상자).
class NicknameForm extends ConsumerStatefulWidget {
  const NicknameForm({super.key, required this.first});

  final bool first;

  @override
  ConsumerState<NicknameForm> createState() => _NicknameFormState();
}

class _NicknameFormState extends ConsumerState<NicknameForm> {
  late final _input = TextEditingController(
    text: widget.first
        ? ref.read(homeProvider.notifier).defaultNickname
        : ref.read(homeProvider).profile.nickname,
  );
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _busy = true);
    final error = await ref
        .read(homeProvider.notifier)
        .saveNickname(_input.text);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = error;
    });
    if (error == null && !widget.first) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 320,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.first ? '닉네임을 정해 주세요' : '닉네임 변경',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _input,
            autofocus: true,
            maxLength: nicknameMax,
            decoration: InputDecoration(
              helperText: '$nicknameMin~$nicknameMax자, 한글·영문·숫자',
              errorText: _error,
            ),
            onSubmitted: (_) => unawaited(_save()),
          ),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: _busy ? null : () => unawaited(_save()),
            child: Text(widget.first ? '시작하기' : '저장'),
          ),
        ],
      ),
    );
  }
}
