import 'package:flutter/material.dart';

// 게임 팔레트(맵 바닥 올리브, 앰버 강조). 홈·무기·설정 화면이 같이 쓴다.
const bgColor = Color(0xFF232B22);
const panelColor = Color(0xFF3A4A3A);
const amberColor = Color(0xFFE8B33A);
const lightColor = Color(0xFFE3E6D8);

/// 등급 배지 "E".
class GradeBadge extends StatelessWidget {
  const GradeBadge(this.grade, {super.key});

  final String grade;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
    decoration: BoxDecoration(
      border: Border.all(color: amberColor, width: 2),
      borderRadius: BorderRadius.circular(4),
    ),
    child: Text(
      grade,
      style: const TextStyle(color: amberColor, fontWeight: FontWeight.w900),
    ),
  );
}
