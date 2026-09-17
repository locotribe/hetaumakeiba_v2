// lib/widgets/ticket/parts/ticket_serial_number_line.dart

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:hetaumakeiba_v2/widgets/ticket/util/ticket_fonts.dart';

/// 券面最下段の下端番号の表示位置（左端の幅比率）。エミュレーターでの微調整用。
const double kSerialLineLeftRatio = 0.26;

/// 券面最下段の下端番号の表示位置（上端の高さ比率）。エミュレーターでの微調整用。
// [修正] 表示枠の高さを 11.2 → 約16.2 に広げるため 0.955 → 0.935 に変更 (v.2026.9.18+26091801)
const double kSerialLineTopRatio = 0.935;

/// 券面最下段の下端番号の右余白。
const double kSerialLineRightPadding = 2.0;

// [追加] 数字を縦方向に引き伸ばす倍率（1.0で等倍）。枠の高さ ≧ fontSize × 倍率 にすること (v.2026.9.18+26091801)
const double kSerialLineScaleY = 1.25;

/// 下端番号40桁のうち、QRコードから転記できる桁かどうか（0始まりインデックス）。
/// 1〜13桁目, 21〜27桁目, 29〜34桁目 がQR由来。それ以外は表示用の乱数で埋める。
bool _isQrDerivedIndex(int i) {
  return (i >= 0 && i <= 12) || (i >= 20 && i <= 26) || (i >= 28 && i <= 33);
}

/// FNV-1a 32bit ハッシュ。馬券ごとに固定の乱数シードを得るために使う。
int _fnv1a32(String s) {
  int hash = 0x811c9dc5;
  for (final int c in s.codeUnits) {
    hash ^= c;
    hash = (hash * 0x01000193) & 0xFFFFFFFF;
  }
  return hash;
}

/// 券面表示用の下端番号文字列（13・13・8・6桁区切り）を生成する。
/// 生成できない場合は null を返す。
String? buildTicketSerialNumberText(Map<String, dynamic> ticketData) {
  final dynamic raw = ticketData['下端番号'];
  if (raw is! String) {
    return null;
  }
  final String digits = raw.replaceAll(' ', '');
  if (digits.length != 40) {
    return null;
  }

  final dynamic qr = ticketData['QR'];
  final String seedSource = qr is String && qr.isNotEmpty ? qr : digits;
  final Random random = Random(_fnv1a32(seedSource));

  final StringBuffer buffer = StringBuffer();
  for (int i = 0; i < 40; i++) {
    if (_isQrDerivedIndex(i)) {
      buffer.write(digits[i]);
    } else {
      buffer.write(random.nextInt(10));
    }
    if (i == 12 || i == 25 || i == 33) {
      buffer.write('  ');
    }
  }
  return buffer.toString();
}

/// 実際の馬券の最下段に印字される数字列を模した表示ウィジェット。
/// 見た目の再現のみを目的とし、QR由来でない桁は馬券ごとに固定の乱数で埋める。
class TicketSerialNumberLine extends StatelessWidget {
  final Map<String, dynamic> ticketData;

  const TicketSerialNumberLine({
    super.key,
    required this.ticketData,
  });

  @override
  Widget build(BuildContext context) {
    final String? text = buildTicketSerialNumberText(ticketData);
    if (text == null) {
      return const SizedBox.shrink();
    }

    // [修正] Transform.scale で縦方向のみ拡大し、数字を縦長にする (v.2026.9.18+26091801)
    return Transform.scale(
      scaleX: 1.0,
      scaleY: kSerialLineScaleY,
      alignment: Alignment.centerRight,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerRight,
        child: Text(
          text,
          maxLines: 1,
          softWrap: false,
          style: ticketGothic(
            color: Colors.black,
            fontSize: 12,
            height: 1.0,
          ).copyWith(
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ),
    );
  }
}