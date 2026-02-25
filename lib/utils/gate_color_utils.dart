import 'package:flutter/material.dart';

/// int型に対する枠番カラーの拡張メソッド
extension GateColorExtension on int {
  /// 枠番に応じた背景色を取得する
  Color get gateBackgroundColor {
    switch (this) {
      case 1: return Colors.white;
      case 2: return Colors.black;
      case 3: return Colors.red;
      case 4: return Colors.blue;
      case 5: return Colors.yellow;
      case 6: return Colors.green;
      case 7: return Colors.orange;
      case 8: return Colors.pink.shade200;
      default: return Colors.grey; // 不明な場合はグレー
    }
  }

  /// 枠番の背景色に応じた、見やすい文字色を取得する
  Color get gateTextColor {
    switch (this) {
      case 1: // 白枠
      case 5: // 黄枠
        return Colors.black;
      default:
        return Colors.white;
    }
  }
}

/// String型に対する枠番カラーの拡張メソッド（文字列から変換する画面用）
extension GateColorStringExtension on String {
  Color get gateBackgroundColor {
    final gateNum = int.tryParse(this) ?? 0;
    return gateNum.gateBackgroundColor;
  }

  Color get gateTextColor {
    final gateNum = int.tryParse(this) ?? 0;
    return gateNum.gateTextColor;
  }
}