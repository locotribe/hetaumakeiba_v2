import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:hetaumakeiba_v2/logic/analysis/volatility_analyzer.dart';

class HorseWeightCard extends StatelessWidget {
  final HorseWeightAnalysisResult result;

  const HorseWeightCard({super.key, required this.result});

  @override
  Widget build(BuildContext context) {
    if (result.winningWeights.isEmpty) {
      return const SizedBox.shrink();
    }

    final avg = result.averageWinningWeight;
    final median = result.medianWinningWeight;
    final min = result.winningWeights.reduce((a, b) => a < b ? a : b);
    final max = result.winningWeights.reduce((a, b) => a > b ? a : b);

    // [修正] 増減別のグラフデータ生成ロジックをリファクタリング (v.1.1)
    List<BarChartGroupData> changeBarGroups = [];
    final changeCategories = ['-10kg以下', '-4~-8kg', '-2~+2kg', '+4~+8kg', '+10kg以上'];
    int changeXIndex = 0;
    for (String cat in changeCategories) {
      final stats = result.changeStats[cat];
      if (stats != null) {
        changeBarGroups.add(_createBarGroup(changeXIndex, stats.win, stats.place, stats.show));
      }
      changeXIndex++;
    }

    // [追加] 絶対値階級別のグラフデータ生成と最多出走帯の算出 (v.1.1)
    List<BarChartGroupData> absoluteBarGroups = [];
    final absoluteCategories = ['~439kg', '440~459kg', '460~479kg', '480~499kg', '500~519kg', '520kg~'];
    int absXIndex = 0;
    String volumeZone = '';
    int maxTotal = -1;

    for (String cat in absoluteCategories) {
      final stats = result.absoluteStats[cat];
      if (stats != null) {
        absoluteBarGroups.add(_createBarGroup(absXIndex, stats.win, stats.place, stats.show));
        if (stats.total > maxTotal) {
          maxTotal = stats.total;
          volumeZone = cat;
        }
      }
      absXIndex++;
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('勝ち馬の馬体重傾向',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.scale, color: Colors.brown, size: 36),
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('中央値: ${median.toStringAsFixed(1)} kg (実態)',
                      style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.deepOrange)),
                  const SizedBox(height: 4),
                  Text('平均値: ${avg.toStringAsFixed(1)} kg',
                      style: const TextStyle(fontSize: 14, color: Colors.black87)),
                ],
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 8.0),
                // [追加] サマリーに最多出走帯（ボリュームゾーン）を追加 (v.1.1)
                child: Text(
                    '範囲: ${min.toStringAsFixed(0)}kg 〜 ${max.toStringAsFixed(0)}kg\n'
                        '最多出走帯: $volumeZone'),
              ),
            ),
            const Divider(height: 32),

            // [追加] 絶対値のグラフセクション (v.1.1)
            const Text('馬体重帯別 実績 (絶対値)',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            _buildLegend(),
            const SizedBox(height: 24),
            _buildBarChart(absoluteBarGroups, absoluteCategories, result.absoluteStats),

            const Divider(height: 32),

            // [修正] 既存の増減別グラフセクションの描画メソッド適用 (v.1.1)
            const Text('馬体重増減別 実績',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            _buildLegend(),
            const SizedBox(height: 24),
            _buildBarChart(changeBarGroups, changeCategories, result.changeStats),

            const Divider(height: 32),

            // [追加] 絶対値の勝率・連対率・複勝率テキストリスト (v.1.1)
            const Text('馬体重別成績',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('勝ち馬の平均馬体重: ${avg.toStringAsFixed(1)} kg',
                style: const TextStyle(fontSize: 14)),
            const SizedBox(height: 16),
            ...absoluteCategories.map((cat) {
              final stats = result.absoluteStats[cat];
              if (stats == null || stats.total == 0) return const SizedBox.shrink();
              final winRate = (stats.win / stats.total) * 100;
              final placeRate = (stats.place / stats.total) * 100;
              final showRate = (stats.show / stats.total) * 100;

              return Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(cat, style: const TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(
                      '勝率 ${winRate.toStringAsFixed(1)}% / '
                          '連対率 ${placeRate.toStringAsFixed(1)}% / '
                          '複勝率 ${showRate.toStringAsFixed(1)}%\n'
                          '(${stats.total}頭)',
                      style: const TextStyle(color: Colors.black54),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  // [追加] 凡例生成メソッド (v.1.1)
  Widget _buildLegend() {
    return Wrap(
      spacing: 12,
      runSpacing: 4,
      children: [
        Row(mainAxisSize: MainAxisSize.min, children: const [
          Icon(Icons.square, color: Colors.amber, size: 12),
          SizedBox(width: 4),
          Text('勝数', style: TextStyle(fontSize: 11))
        ]),
        Row(mainAxisSize: MainAxisSize.min, children: const [
          Icon(Icons.square, color: Colors.blueGrey, size: 12),
          SizedBox(width: 4),
          Text('連対数(2着内)', style: TextStyle(fontSize: 11))
        ]),
        Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.square, color: Colors.brown.shade400, size: 12),
          const SizedBox(width: 4),
          const Text('複勝数(3着内)', style: TextStyle(fontSize: 11))
        ]),
      ],
    );
  }

  // [追加] バーデータ生成メソッド (v.1.1)
  BarChartGroupData _createBarGroup(int x, int win, int place, int show) {
    return BarChartGroupData(
      x: x,
      barRods: [
        BarChartRodData(
          toY: win.toDouble(),
          color: Colors.amber,
          width: 10,
          borderRadius: BorderRadius.circular(2),
        ),
        BarChartRodData(
          toY: place.toDouble(),
          color: Colors.blueGrey,
          width: 10,
          borderRadius: BorderRadius.circular(2),
        ),
        BarChartRodData(
          toY: show.toDouble(),
          color: Colors.brown.shade400,
          width: 10,
          borderRadius: BorderRadius.circular(2),
        ),
      ],
    );
  }

  // [追加] チャート描画メソッド (v.1.1)
  Widget _buildBarChart(List<BarChartGroupData> barGroups, List<String> categories, Map<String, WeightStats> statsMap) {
    return SizedBox(
      height: 180,
      child: BarChart(
        BarChartData(
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                return BarTooltipItem(
                  '${rod.toY.toInt()}',
                  const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                );
              },
            ),
          ),
          alignment: BarChartAlignment.spaceAround,
          barGroups: barGroups,
          borderData: FlBorderData(show: false),
          gridData: FlGridData(show: true, drawVerticalLine: false),
          titlesData: FlTitlesData(
            show: true,
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 42,
                getTitlesWidget: (value, meta) {
                  if (value.toInt() >= 0 && value.toInt() < categories.length) {
                    String cat = categories[value.toInt()];
                    int total = statsMap[cat]?.total ?? 0;
                    return Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text('$cat\n($total頭)',
                          style: const TextStyle(fontSize: 10),
                          textAlign: TextAlign.center),
                    );
                  }
                  return const Text('');
                },
              ),
            ),
            topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
        ),
      ),
    );
  }
}