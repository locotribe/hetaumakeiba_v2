import 'package:flutter/material.dart';
// [追加] 枠番の色付きチップに使う枠カラー拡張 (v.2026.9.24+26092402)
import 'package:hetaumakeiba_v2/utils/gate_color_utils.dart';

// 6列目・7列目: 時計・上がり最速セル（共通）
class TrackStatsCell extends StatelessWidget {
  final String? formattedValue;
  final String? trackCondition;
  final dynamic cushionValue;
  final dynamic moistureGoal;
  final dynamic moisture4c;
  final String? venueAndDistance;
  final Color textColor;
  // [追加] 時計・上がりを出したレースの名前と日付（'YYYY/MM/DD'）。未指定なら表示しない (v.2026.9.22+26092207)
  final String? raceName;
  final String? date;
  // [追加] その時計・上がりを出した走の枠番・着順・人気。未指定なら表示しない (v.2026.9.24+26092402)
  final int? frameNumber;
  final int? finishRank;
  final int? popularity;

  const TrackStatsCell({
    Key? key,
    required this.formattedValue,
    required this.trackCondition,
    required this.cushionValue,
    required this.moistureGoal,
    required this.moisture4c,
    required this.venueAndDistance,
    required this.textColor,
    this.raceName,
    this.date,
    // [追加] 枠番・着順・人気 (v.2026.9.24+26092402)
    this.frameNumber,
    this.finishRank,
    this.popularity,
  }) : super(key: key);

  /// 'YYYY/MM/DD' を 'YY.MM.DD' に整形する（例: '2025/05/17' → '25.05.17'）。解析できなければ空文字。
  static String _formatDate(String? date) {
    if (date == null) return '';
    final match = RegExp(r'^\d{2}(\d{2})[/\-.](\d{1,2})[/\-.](\d{1,2})').firstMatch(date);
    if (match == null) return '';
    return '${match.group(1)}.${match.group(2)!.padLeft(2, '0')}.${match.group(3)!.padLeft(2, '0')}';
  }

  /// レース名からグレード表記（(GI) 等）を除く
  static String _formatRaceName(String? raceName) {
    if (raceName == null) return '';
    return raceName
        .replaceAll(RegExp(r'\((J\.?G[I]{1,3}|G[I]{1,3}|L|OP)\)', caseSensitive: false), '')
        .trim();
  }

  // [追加] 枠番の色付きチップを作る。gateNumber が null または 1〜8 以外はグレー。 (v.2026.9.24+26092402)
  Widget _buildGateChip(int gateNumber) {
    return Container(
      width: 16,
      height: 16,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: gateNumber.gateBackgroundColor,
        border: gateNumber == 1 ? Border.all(color: Colors.grey) : null,
        borderRadius: BorderRadius.circular(3),
      ),
      child: Text(
        '$gateNumber',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: gateNumber.gateTextColor,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // [修正] 上段にレースの日付と名前を追加（長い名前は「…」で切り、時計の数字は縮めない）。
    // 時計・上がりの数字を12→17に拡大。列幅に収まらない場合のみ縮小する (v.2026.9.22+26092207)
    final dateLabel = _formatDate(date);
    final raceLabel = _formatRaceName(raceName);
    // [追加] 枠番・着順・人気の行を出すかどうか (v.2026.9.24+26092402)
    final bool hasResultLine =
        frameNumber != null || finishRank != null || popularity != null;
    return Container(
      width: double.infinity,
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (dateLabel.isNotEmpty)
            Text(
              dateLabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: textColor),
            ),
          if (raceLabel.isNotEmpty)
            Text(
              raceLabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 9, color: textColor),
            ),
          if (dateLabel.isNotEmpty || raceLabel.isNotEmpty) const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  formattedValue ?? '--',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: textColor),
                ),
                const SizedBox(height: 2),
                Text(
                  '${trackCondition ?? '--'} / ${cushionValue != null ? 'C:$cushionValue' : '--'}',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: textColor),
                ),
                const SizedBox(height: 2),
                Text(
                  (moistureGoal != null || moisture4c != null)
                      ? 'G:${moistureGoal ?? '-'}\n4c:${moisture4c ?? '-'}'
                      : '--',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: textColor),
                ),
                const SizedBox(height: 2),
                Text(
                  (() {
                    final raw = venueAndDistance;
                    if (raw == null || raw.isEmpty) return '--';
                    final match = RegExp(r'^(.*?)([芝ダ障].*)$').firstMatch(raw);
                    if (match != null) {
                      final v = match.group(1)!.replaceAll(RegExp(r'[0-9０-９\s]'), '');
                      return '$v ${match.group(2)}';
                    }
                    return raw;
                  })(),
                  style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: textColor),
                ),
                // [追加] 枠番(色付きチップ)・着順・人気を1行で表示 (v.2026.9.24+26092402)
                if (hasResultLine) ...[
                  const SizedBox(height: 2),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (frameNumber != null) ...[
                        _buildGateChip(frameNumber!),
                        const SizedBox(width: 3),
                      ],
                      Text(
                        '${finishRank != null ? '$finishRank着' : '-着'} ${popularity != null ? '$popularity人気' : '-人気'}',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: textColor),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
