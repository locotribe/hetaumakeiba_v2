// lib/widgets/odds_tabs/odds_list_tab.dart

import 'package:flutter/material.dart';
import '../../models/race_data.dart';
import '../../utils/gate_color_utils.dart';

class OddsListTab extends StatelessWidget {
  final List<Map<String, String>> oddsData;
  final String title;
  final PredictionRaceData raceData; // 馬の情報を検索するために追加

  const OddsListTab({
    super.key,
    required this.oddsData,
    required this.title,
    required this.raceData,
  });

  // 馬番をキーに馬の詳細情報を高速に引くためのマップを作成
  Map<int, PredictionHorseDetail> get _horseMap => {
    for (var h in raceData.horses) h.horseNumber: h,
  };

  @override
  Widget build(BuildContext context) {
    if (oddsData.isEmpty) {
      return const Center(child: Text('オッズデータがありません。'));
    }

    final horseMap = _horseMap;

    return ListView.builder(
      itemCount: oddsData.length,
      padding: const EdgeInsets.symmetric(vertical: 4),
      itemBuilder: (context, index) {
        final item = oddsData[index];
        final combinationStr = item['combination'] ?? '';

        // 組み合わせ（例: "1_01", "4-0102"）から馬番のリストを抽出する
        final List<int> horseNumbers = _parseCombination(combinationStr);

        return Container(
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
            // 偶数行にわずかな色をつけて視認性を向上
            color: index % 2 == 0 ? Colors.transparent : Colors.grey.withOpacity(0.05),
          ),
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
          child: Row(
            children: [
              // 1. 馬番アイコン（1頭または2頭）
              _buildHorseIcons(horseNumbers, horseMap),
              const SizedBox(width: 12),

              // 2. 馬名（頭文字3文字）
              Expanded(
                child: _buildHorseNames(horseNumbers, horseMap),
              ),

              // 3. オッズ
              Text(
                '${item['odds']}',
                style: const TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                  fontFamily: 'monospace', // 数字の桁を揃える
                ),
              ),
              const Text(
                ' 倍',
                style: TextStyle(color: Colors.red, fontSize: 10, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        );
      },
    );
  }

  /// 文字列から馬番を抽出する (例: "1_01" -> [1], "4-0102" -> [1, 2])
  List<int> _parseCombination(String combo) {
    // 数字以外の文字（-, _）で分割し、かつ連続する数字を2桁ずつに分解する
    // 例: "0102" -> ["01", "02"]
    final List<int> result = [];

    // まずハイフンやアンダースコアで分割を試みる
    final parts = combo.split(RegExp(r'[-_]'));

    // type番号（b1, b4等）が含まれている場合は最後の要素を対象にする
    String target = parts.last;

    if (target.length >= 4) {
      // 2頭（馬連など）: "0102" 形式
      for (int i = 0; i < target.length; i += 2) {
        if (i + 2 <= target.length) {
          result.add(int.tryParse(target.substring(i, i + 2)) ?? 0);
        }
      }
    } else {
      // 1頭（単複）: "01" 形式
      result.add(int.tryParse(target) ?? 0);
    }
    return result.where((n) => n > 0).toList();
  }

  /// 馬番のアイコン（枠色付き）を構築
  Widget _buildHorseIcons(List<int> numbers, Map<int, PredictionHorseDetail> map) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: numbers.map((n) {
        final horse = map[n];
        final gateNum = horse?.gateNumber ?? 0;
        final bgColor = gateNum.gateBackgroundColor;
        final textColor = gateNum.gateTextColor;

        return Container(
          width: 26,
          height: 26,
          margin: const EdgeInsets.only(right: 4),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(4),
            border: gateNum == 1 ? Border.all(color: Colors.grey.shade400) : null,
            boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 1, offset: Offset(0, 1))],
          ),
          child: Text(
            n.toString(),
            style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 13),
          ),
        );
      }).toList(),
    );
  }

  /// 馬名（頭文字3文字）を構築
  Widget _buildHorseNames(List<int> numbers, Map<int, PredictionHorseDetail> map) {
    final List<String> names = numbers.map((n) {
      final name = map[n]?.horseName ?? '不明';
      if (name.length > 3) {
        return '${name.substring(0, 3)}..';
      }
      return name;
    }).toList();

    return Text(
      names.join(numbers.length > 1 ? ' - ' : ''),
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.bold,
        color: Colors.black87,
      ),
      overflow: TextOverflow.ellipsis,
    );
  }
}