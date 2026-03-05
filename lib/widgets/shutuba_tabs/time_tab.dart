import 'package:flutter/material.dart';

// 6列目・7列目: 時計・上がり最速セル（共通）
class TrackStatsCell extends StatelessWidget {
  final String? formattedValue;
  final String? trackCondition;
  final dynamic cushionValue;
  final dynamic moistureGoal;
  final dynamic moisture4c;
  final String? venueAndDistance;
  final Color textColor;

  const TrackStatsCell({
    Key? key,
    required this.formattedValue,
    required this.trackCondition,
    required this.cushionValue,
    required this.moistureGoal,
    required this.moisture4c,
    required this.venueAndDistance,
    required this.textColor,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      alignment: Alignment.center,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              formattedValue ?? '--',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: textColor),
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
          ],
        ),
      ),
    );
  }
}