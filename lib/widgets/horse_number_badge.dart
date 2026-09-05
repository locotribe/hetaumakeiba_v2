// lib/widgets/horse_number_badge.dart

import 'package:flutter/material.dart';
import 'package:hetaumakeiba_v2/utils/gate_color_utils.dart';

// [追加] 枠色を背景にした馬番バッジ。出馬表と目線を合わせるための共通部品 (v.2026.9.5+26090506)
class HorseNumberBadge extends StatelessWidget {
  final int horseNumber;
  final int gateNumber;
  final double size;

  const HorseNumberBadge({
    super.key,
    required this.horseNumber,
    required this.gateNumber,
    this.size = 24.0,
  });

  @override
  Widget build(BuildContext context) {
    final bool isValid = horseNumber > 0;
    final Color background =
        gateNumber > 0 ? gateNumber.gateBackgroundColor : Colors.grey.shade300;
    final Color foreground =
        gateNumber > 0 ? gateNumber.gateTextColor : Colors.black54;

    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(4.0),
        border: Border.all(color: Colors.grey.shade400, width: 0.5),
      ),
      child: Text(
        isValid ? '$horseNumber' : '-',
        style: TextStyle(
          color: foreground,
          fontSize: size * 0.55,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
