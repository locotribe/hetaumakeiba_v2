// lib/widgets/odds_tabs/odds_matrix_widget.dart

import 'package:flutter/material.dart';
import '../../models/race_data.dart';
import '../../utils/gate_color_utils.dart';

class OddsMatrixWidget extends StatelessWidget {
  final List<Map<String, String>> oddsData;
  final PredictionRaceData raceData;
  final String type; // b4, b5, b6

  const OddsMatrixWidget({super.key, required this.oddsData, required this.raceData, required this.type});

  @override
  Widget build(BuildContext context) {
    final horseCount = raceData.horses.length;

    // 1. 人気TOP10の抽出
    final top10 = List<Map<String, String>>.from(oddsData)
      ..sort((a, b) => (double.tryParse(a['odds']!) ?? 999).compareTo(double.tryParse(b['odds']!) ?? 999));
    final displayTop10 = top10.take(10).toList();

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              Icon(Icons.emoji_events, size: 18, color: Colors.amber),
              SizedBox(width: 8),
              Text('人気上位10の組み合わせ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            ],
          ),
        ),
        _buildTop10Grid(displayTop10),
        const Divider(height: 32),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              Icon(Icons.grid_on, size: 18, color: Colors.blueGrey),
              SizedBox(width: 8),
              Text('オッズ確認用マトリクス', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            ],
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: _buildTable(horseCount),
          ),
        ),
        const SizedBox(height: 50),
      ],
    );
  }

  /// 安全に馬番を解析するヘルパー
  List<int> _extractHorseNumbers(String combination) {
    // 例: "4-0102" -> "0102"
    final cleanStr = combination.split('-').last;
    if (cleanStr.length < 4) return [];

    final h1 = int.tryParse(cleanStr.substring(0, 2)) ?? 0;
    final h2 = int.tryParse(cleanStr.substring(2, 4)) ?? 0;
    return [h1, h2];
  }

  Widget _buildTop10Grid(List<Map<String, String>> data) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Wrap(
        spacing: 8, runSpacing: 8,
        children: data.map((item) {
          final nums = _extractHorseNumbers(item['combination'] ?? '');
          if (nums.length < 2) return const SizedBox.shrink();

          return Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(4),
              boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 1, offset: Offset(0, 1))],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _miniHorseBox(nums[0]),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 2),
                  child: Text('-', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                ),
                _miniHorseBox(nums[1]),
                const SizedBox(width: 8),
                Text(item['odds']!, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red, fontSize: 14)),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _miniHorseBox(int num) {
    final horse = raceData.horses.firstWhere((h) => h.horseNumber == num,
        orElse: () => PredictionHorseDetail(horseId: '', horseNumber: num, gateNumber: 0, horseName: '', sexAndAge: '', jockey: '', jockeyId: '', carriedWeight: 0, trainerName: '', trainerAffiliation: '', isScratched: false));

    final gateNum = horse.gateNumber;
    return Container(
      width: 22, height: 22,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: gateNum.gateBackgroundColor,
        borderRadius: BorderRadius.circular(2),
        border: gateNum == 1 ? Border.all(color: Colors.grey.shade400) : Border.all(color: Colors.black.withOpacity(0.1)),
      ),
      child: Text(num.toString(),
          style: TextStyle(color: gateNum.gateTextColor, fontSize: 11, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildTable(int count) {
    final Map<String, String> oddsLookup = {
      for (var item in oddsData) item['combination']!.split('-').last: item['odds']!
    };

    return Table(
      defaultColumnWidth: const FixedColumnWidth(55),
      border: TableBorder.all(color: Colors.grey.shade300),
      children: [
        TableRow(
          decoration: BoxDecoration(color: Colors.grey.shade100),
          children: [
            const SizedBox(height: 35, child: Center(child: Text('▼\\▶', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)))),
            ...List.generate(count, (i) => Center(child: _miniHorseBox(i + 1))),
          ],
        ),
        ...List.generate(count, (rowIdx) {
          final rNum = rowIdx + 1;
          return TableRow(
            children: [
              Container(
                height: 35,
                color: Colors.grey.shade100,
                child: Center(child: _miniHorseBox(rNum)),
              ),
              ...List.generate(count, (colIdx) {
                final cNum = colIdx + 1;
                if (rNum == cNum) return Container(height: 35, color: Colors.grey.shade300);

                if ((type == 'b4' || type == 'b5') && rNum > cNum) {
                  return Container(height: 35, color: Colors.grey.shade50);
                }

                final key = rNum.toString().padLeft(2, '0') + cNum.toString().padLeft(2, '0');
                final odds = oddsLookup[key] ?? '--';
                final val = double.tryParse(odds) ?? 999.0;
                final isLow = val <= 9.9;

                return SizedBox(
                  height: 35,
                  child: Center(
                    child: Text(
                      odds,
                      style: TextStyle(
                          fontSize: 11,
                          color: isLow ? Colors.red : Colors.black,
                          fontWeight: isLow ? FontWeight.bold : FontWeight.normal
                      ),
                    ),
                  ),
                );
              }),
            ],
          );
        }),
      ],
    );
  }
}