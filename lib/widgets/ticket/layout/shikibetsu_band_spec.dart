// lib/widgets/ticket/layout/shikibetsu_band_spec.dart

import 'package:flutter/material.dart';

/// 式別帯（馬券中央の縦帯）の見た目を決める値。
/// 帯のフレーム自体は Single / Dual で構造が異なるため各カードが持ち、
/// このクラスは「どの式別なら何色・何の英字か」だけを表す。
class ShikibetsuBandSpec {
  /// 上下に表示する英字ラベル（改行を含む場合がある）
  final String label;
  /// ラベルの文字色
  final Color labelColor;
  /// ラベル部分の背景色
  final Color labelBackgroundColor;
  /// 中段（式別の縦書き）の背景色
  final Color middleBackgroundColor;
  /// 中段の文字色
  final Color middleTextColor;
  /// BettingTicketCard がラベルを包む SizedBox の高さ（1行=15.0 / 2行=30.0）
  final double singleLabelHeight;

  const ShikibetsuBandSpec({
    required this.label,
    required this.labelColor,
    required this.labelBackgroundColor,
    required this.middleBackgroundColor,
    required this.middleTextColor,
    required this.singleLabelHeight,
  });
}

/// 式別名から帯のスペックを返す。該当しない場合は null を返す。
/// null のときのフォールバックは呼び出し側（カード）が持つ。Single と Dual で異なるため。
ShikibetsuBandSpec? resolveShikibetsuBandSpec(String shikibetsuName) {
  switch (shikibetsuName) {
    case '単勝':
      return const ShikibetsuBandSpec(
        label: 'WIN',
        labelColor: Colors.black,
        labelBackgroundColor: Colors.transparent,
        middleBackgroundColor: Colors.transparent,
        middleTextColor: Colors.black,
        singleLabelHeight: 15.0,
      );
    case '複勝':
      return const ShikibetsuBandSpec(
        label: 'PLACE\nSHOW',
        labelColor: Colors.white,
        labelBackgroundColor: Colors.black,
        middleBackgroundColor: Colors.transparent,
        middleTextColor: Colors.black,
        singleLabelHeight: 30.0,
      );
    case '馬連':
      return const ShikibetsuBandSpec(
        label: 'QUINELLA',
        labelColor: Colors.black,
        labelBackgroundColor: Colors.transparent,
        middleBackgroundColor: Colors.transparent,
        middleTextColor: Colors.black,
        singleLabelHeight: 15.0,
      );
    case '馬単':
      return const ShikibetsuBandSpec(
        label: 'EXACTA',
        labelColor: Colors.white,
        labelBackgroundColor: Colors.black,
        middleBackgroundColor: Colors.transparent,
        middleTextColor: Colors.black,
        singleLabelHeight: 15.0,
      );
    case 'ワイド':
      return const ShikibetsuBandSpec(
        label: 'QUINELLA\nPLACE',
        labelColor: Colors.white,
        labelBackgroundColor: Colors.black,
        middleBackgroundColor: Colors.transparent,
        middleTextColor: Colors.black,
        singleLabelHeight: 30.0,
      );
    case '枠連':
      return const ShikibetsuBandSpec(
        label: 'BRACKET\nQUINELLA',
        labelColor: Colors.white,
        labelBackgroundColor: Colors.black,
        middleBackgroundColor: Colors.black,
        middleTextColor: Colors.white,
        singleLabelHeight: 30.0,
      );
    case '3連複':
      return const ShikibetsuBandSpec(
        label: 'TRIO',
        labelColor: Colors.black,
        labelBackgroundColor: Colors.transparent,
        middleBackgroundColor: Colors.transparent,
        middleTextColor: Colors.black,
        singleLabelHeight: 15.0,
      );
    case '3連単':
      return const ShikibetsuBandSpec(
        label: 'TRIFECTA',
        labelColor: Colors.white,
        labelBackgroundColor: Colors.black,
        middleBackgroundColor: Colors.transparent,
        middleTextColor: Colors.black,
        singleLabelHeight: 15.0,
      );
    default:
      return null;
  }
}
