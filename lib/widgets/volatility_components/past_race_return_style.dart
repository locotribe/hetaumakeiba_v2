// lib/widgets/volatility_components/past_race_return_style.dart

// [追加] ローテ・血統タブの見た目の調整 Step2: 過去の出走馬の表と該当馬カードで使う、回収率（単回・複回）の文字と色 (v.2026.10.19+26101907)

import 'package:flutter/material.dart';

/// 区分の過去の出走がこれより少ないときは、回収率に色を付けない（大穴1回で赤くなるのを防ぐ）。
const int kReturnColorMinStarts = 3;

/// 回収率(%)の文字。例 '132%'。計算できないときは '-'。
String pastRaceReturnText(double? percent) =>
    percent == null ? '-' : '${percent.toStringAsFixed(0)}%';

/// 回収率(%)の色。200%以上は赤、100%以上はオレンジ、80%以上は黒、80%未満は灰色。
/// 計算できないとき、または区分の過去の出走 [starts] が [kReturnColorMinStarts] 未満のときは黒（色を付けない）。
Color pastRaceReturnColor(double? percent, int starts) {
  if (percent == null || starts < kReturnColorMinStarts) return Colors.black87;
  if (percent >= 200) return Colors.red.shade700;
  if (percent >= 100) return Colors.orange.shade800;
  if (percent >= 80) return Colors.black87;
  return Colors.grey;
}
