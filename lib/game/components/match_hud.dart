import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flutter/painting.dart' show FontWeight, TextStyle;

import '../../rules/balance.dart';
import '../net/match_sync.dart';
import '../soldier_game.dart';

/// 1대1 화면 HUD: 위 가운데 점수·남은 시간, 오른쪽 위 킬 로그, 아래 가운데 내 체력,
/// 맞으면 가장자리 빨간 깜빡임, 죽으면 "전사" + 부활 카운트다운.
class MatchHud extends Component with HasGameReference<SoldierGame> {
  MatchHud(this.sync);

  final MatchSync sync;

  static TextPaint _text(double size, {Color color = _light}) => TextPaint(
    style: TextStyle(color: color, fontSize: size, fontWeight: FontWeight.w700),
  );

  static const _light = Color(0xFFE3E6D8);
  static final _score = _text(18);
  static final _time = _text(12);
  static final _log = _text(11);
  static final _hpText = _text(11);
  static final _dead = _text(34, color: const Color(0xFFE0563F));
  static final _countdown = _text(20);
  static final _barBack = Paint()..color = const Color(0x99000000);
  static final _barFill = Paint()..color = const Color(0xFF4FA3E0);
  static final _deadShade = Paint()..color = const Color(0x99000000);

  @override
  void render(Canvas canvas) {
    final size = game.size;
    _renderScore(canvas, size);
    _renderKillLog(canvas, size);
    _renderHp(canvas, size);
    if (sync.hurtFlash > 0) _renderHurt(canvas, size);
    if (sync.isDead) _renderDead(canvas, size);
  }

  void _renderScore(Canvas canvas, Vector2 size) {
    final secs = (sync.remainingMs / 1000).ceil();
    final time = '${secs ~/ 60}:${(secs % 60).toString().padLeft(2, '0')}';
    _score.render(
      canvas,
      'A ${sync.scoreA} : ${sync.scoreB} B',
      Vector2(size.x / 2, 8),
      anchor: Anchor.topCenter,
    );
    _time.render(
      canvas,
      time,
      Vector2(size.x / 2, 32),
      anchor: Anchor.topCenter,
    );
  }

  /// 무기 슬롯(오른쪽 위) 아래에 최근 3개.
  void _renderKillLog(Canvas canvas, Vector2 size) {
    for (final (i, k) in sync.killLog.indexed) {
      _log.render(
        canvas,
        '${sync.nameOf(k.killer)} ▸ ${sync.nameOf(k.victim)}  ${k.weapon}'
        '${k.crit ? '  CRIT' : ''}',
        Vector2(size.x - 16, 84 + i * 16.0),
        anchor: Anchor.topRight,
      );
    }
  }

  void _renderHp(Canvas canvas, Vector2 size) {
    final value = sync.myHp?.value ?? basicSoldier.hp.toDouble();
    final ratio = (value / basicSoldier.hp).clamp(0.0, 1.0);
    const w = 180.0, h = 8.0;
    final left = size.x / 2 - w / 2, top = size.y - 22;
    canvas
      ..drawRect(Rect.fromLTWH(left, top, w, h), _barBack)
      ..drawRect(Rect.fromLTWH(left, top, w * ratio, h), _barFill);
    _hpText.render(
      canvas,
      'HP ${value.ceil()}',
      Vector2(size.x / 2, top - 3),
      anchor: Anchor.bottomCenter,
    );
  }

  void _renderHurt(Canvas canvas, Vector2 size) {
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.x, size.y),
      Paint()
        ..color = Color.fromRGBO(224, 72, 72, 0.55 * sync.hurtFlash)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 28,
    );
  }

  void _renderDead(Canvas canvas, Vector2 size) {
    canvas.drawRect(Rect.fromLTWH(0, 0, size.x, size.y), _deadShade);
    _dead.render(
      canvas,
      '전사',
      Vector2(size.x / 2, size.y / 2 - 30),
      anchor: Anchor.center,
    );
    _countdown.render(
      canvas,
      '${sync.respawnLeft.ceil()}',
      Vector2(size.x / 2, size.y / 2 + 10),
      anchor: Anchor.center,
    );
    // 부스터 선택(3개 중 1개, decisions 12장)은 다음 작업. 이 아래 자리를 비워 둔다.
  }
}
