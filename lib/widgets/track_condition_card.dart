import 'package:flutter/material.dart';
import 'package:hetaumakeiba_v2/models/track_conditions_model.dart';

// [追加] 馬場状態を表示するカード型Widget (v.2026.7.28+26072801)
class TrackConditionCard extends StatelessWidget {
  final TrackConditionRecord record;
  final String lastUpdatedTime;

  const TrackConditionCard({
    super.key,
    required this.record,
    required this.lastUpdatedTime,
  });

  String _getCourseName(int id) {
    String idStr = id.toString();
    if (idStr.length < 6) return "不明";
    String cc = idStr.substring(4, 6);
    final Map<String, String> codes = {
      '01': '札幌', '02': '函館', '03': '福島', '04': '新潟', '05': '東京',
      '06': '中山', '07': '中京', '08': '京都', '09': '阪神', '10': '小倉',
    };
    return codes[cc] ?? "他";
  }

  String _getJapaneseWeekday(String weekDayCode) {
    final Map<String, String> weekdays = {
      'mo': '月', 'tu': '火', 'we': '水', 'th': '木',
      'fr': '金', 'sa': '土', 'su': '日',
    };
    return weekdays[weekDayCode.toLowerCase()] ?? "";
  }

  @override
  Widget build(BuildContext context) {
    final courseName = _getCourseName(record.trackConditionId);
    final jpWeekday = _getJapaneseWeekday(record.weekDay);
    final dateFull = record.date.replaceAll("-", "/");

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      elevation: 4,
      color: Colors.black87,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ヘッダー部分
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '$courseName競馬場',
                  style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Text(
                  '$dateFull $jpWeekday',
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // 数値データ部分
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // クッション値
                Column(
                  children: [
                    const Text('クッション値', style: TextStyle(color: Colors.white70, fontSize: 12)),
                    const SizedBox(height: 4),
                    Text(
                      '${record.cushionValue ?? "-"}',
                      style: const TextStyle(color: Colors.greenAccent, fontSize: 24, fontWeight: FontWeight.bold, fontFamily: 'monospace'),
                    ),
                  ],
                ),
                // 芝含水率
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('芝含水率', style: TextStyle(color: Colors.white70, fontSize: 12)),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const SizedBox(width: 24, child: Text('G:', style: TextStyle(color: Colors.greenAccent, fontSize: 14, fontFamily: 'monospace'))),
                        Text('${record.moistureTurfGoal ?? "-"}%', style: const TextStyle(color: Colors.greenAccent, fontSize: 14, fontFamily: 'monospace')),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        const SizedBox(width: 24, child: Text('4C:', style: TextStyle(color: Colors.greenAccent, fontSize: 14, fontFamily: 'monospace'))),
                        Text('${record.moistureTurf4c ?? "-"}%', style: const TextStyle(color: Colors.greenAccent, fontSize: 14, fontFamily: 'monospace')),
                      ],
                    ),
                  ],
                ),
                // ダート含水率
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('ダ含水率', style: TextStyle(color: Colors.white70, fontSize: 12)),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const SizedBox(width: 24, child: Text('G:', style: TextStyle(color: Colors.orangeAccent, fontSize: 14, fontFamily: 'monospace'))),
                        Text('${record.moistureDirtGoal ?? "-"}%', style: const TextStyle(color: Colors.orangeAccent, fontSize: 14, fontFamily: 'monospace')),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        const SizedBox(width: 24, child: Text('4C:', style: TextStyle(color: Colors.orangeAccent, fontSize: 14, fontFamily: 'monospace'))),
                        Text('${record.moistureDirt4c ?? "-"}%', style: const TextStyle(color: Colors.orangeAccent, fontSize: 14, fontFamily: 'monospace')),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
