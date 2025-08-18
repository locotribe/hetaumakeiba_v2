// lib/utils/grade_utils.dart

import 'package:flutter/material.dart';

/// レースのグレードに応じた色を返します。
/// 障害グレード (J.G1, J.G2, J.G3) と平地グレード (G1, G2, G3) に対応し、
/// それ以外のグレードやグレードが不明な場合は Colors.blueGrey を返します。
Color getGradeColor(String grade) {
  // 渡されたグレード文字列内のローマ数字 (I, II, III) をアラビア数字に変換し、J.GをJGに正規化
  // 'III' -> '3', 'II' -> '2', 'I' -> '1' の順で変換することで、'II'が'I'に先に変換されるのを防ぐ
  String normalizedGrade = grade
      .replaceAll('III', '3')
      .replaceAll('II', '2')
      .replaceAll('I', '1')
      .replaceAll('J.G', 'JG') // J.GをJGに正規化 (例: J.G1 -> JG1)
      .replaceAll(' ', ''); // スペースを除去

  // 厳密な文字列一致で判定
  if (normalizedGrade == 'JG1') return Colors.blue.shade700;   // J・G1
  if (normalizedGrade == 'JG2') return Colors.red.shade700;     // J・G2
  if (normalizedGrade == 'JG3') return Colors.green.shade700;   // J・G3

  if (normalizedGrade == 'G1') return Colors.blue.shade700;    // G1
  if (normalizedGrade == 'G2') return Colors.red.shade700;     // G2
  if (normalizedGrade == 'G3') return Colors.green.shade700;    // G3

  return Colors.black26; // その他のグレードやグレードなしの場合
}
