import 'package:flutter/material.dart';
import 'package:hetaumakeiba_v2/models/historical_match_model.dart';

// [修正] 総合シンクロ率と血統クロス Step4: 点数や回数ではなく、過去の全出走馬を父ごとに数えた着度数（1着-2着-3着-着外）だけを、クッション値別・含水率別に出す。
// 1〜3着の血統が1頭でも欠けると分析を隠す作り・カードの取得ボタン・全体傾向（父・母父）はやめた（取得は血統タブの上の取得カード、父・母父の全体は父・母父の表で見る） (v.2026.10.16+26101617)
class PedigreeCrossAnalysisCard extends StatelessWidget {
  final CrossAnalysisResult result;

  const PedigreeCrossAnalysisCard({
    super.key,
    required this.result,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '過去レース 血統分析（馬場別）',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              _summaryText(),
              style: const TextStyle(fontSize: 12, color: Colors.black54),
            ),
            const SizedBox(height: 12),
            if (result.countedStarts == 0)
              const Text(
                '血統のデータがありません。上の取得カードから、過去の出走馬の戦績・血統を取得してください。',
                style: TextStyle(fontSize: 13, color: Colors.grey),
              )
            else ...[
              DefaultTabController(
                length: 2,
                child: Column(
                  children: [
                    TabBar(
                      isScrollable: true,
                      labelColor: Colors.blue.shade800,
                      unselectedLabelColor: Colors.grey,
                      indicatorColor: Colors.blue.shade800,
                      tabs: const [
                        Tab(text: 'クッション値別'),
                        Tab(text: '含水率別'),
                      ],
                    ),
                    SizedBox(
                      height: 250, // 高さを固定してスクロール可能に
                      child: TabBarView(
                        children: [
                          // クッション値別タブ
                          _buildTripleScrollableLists(
                            title1: '硬い (9.5〜)', list1: result.highCushionSires,
                            title2: '標準 (8.5〜9.4)', list2: result.standardCushionSires,
                            title3: '軟らかい (〜8.4)', list3: result.lowCushionSires,
                          ),
                          // 含水率別タブ
                          _buildScrollableLists(
                            title1: '水分多め (10%〜)', list1: result.highMoistureSires,
                            title2: '乾燥ぎみ (〜9.9%)', list2: result.lowMoistureSires,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (result.racesWithoutCushion > 0 || result.racesWithoutMoisture > 0) ...[
                const SizedBox(height: 8),
                Text(
                  _missingTrackText(),
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  /// 「過去の全出走馬を父ごとに数えた着度数…」の説明と、数えた・数えなかった延べ頭数。
  String _summaryText() {
    final buffer = StringBuffer(
        '過去の全出走馬を父ごとに数えた着度数（1着-2着-3着-着外）。3着以内の多い順。\n'
        '過去の出走 延べ${result.countedStarts}頭で集計');
    if (result.missingStarts > 0) {
      buffer.write('・血統が無い延べ${result.missingStarts}頭は数えていません');
    }
    return buffer.toString();
  }

  /// 馬場のデータが無く、表に入らなかったレースの数。
  String _missingTrackText() {
    final parts = <String>[];
    if (result.racesWithoutCushion > 0) {
      parts.add('クッション値が無いレース${result.racesWithoutCushion}件');
    }
    if (result.racesWithoutMoisture > 0) {
      parts.add('含水率が無いレース${result.racesWithoutMoisture}件');
    }
    return '${parts.join('・')}は、それぞれの表に入っていません。';
  }

  // 2列並びのリスト（含水率で使用）
  Widget _buildScrollableLists({
    required String title1, required List<PedigreeRecordCount> list1,
    required String title2, required List<PedigreeRecordCount> list2,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: _buildListColumn(title1, list1)),
        const SizedBox(width: 8),
        Expanded(child: _buildListColumn(title2, list2)),
      ],
    );
  }

  // 3列並びのリスト（クッション値で使用）
  Widget _buildTripleScrollableLists({
    required String title1, required List<PedigreeRecordCount> list1,
    required String title2, required List<PedigreeRecordCount> list2,
    required String title3, required List<PedigreeRecordCount> list3,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: _buildListColumn(title1, list1)),
        const SizedBox(width: 4),
        Expanded(child: _buildListColumn(title2, list2)),
        const SizedBox(width: 4),
        Expanded(child: _buildListColumn(title3, list3)),
      ],
    );
  }

  // 父の名前と着度数を2行で並べる（列の幅が狭くても着度数が切れないように）
  Widget _buildListColumn(String title, List<PedigreeRecordCount> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black54)),
        ),
        Expanded(
          child: items.isEmpty
              ? const Text('-', style: TextStyle(color: Colors.grey))
              : ListView.builder(
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: 6.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.name, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    Text(item.recordText, style: const TextStyle(fontSize: 11, color: Colors.blue)),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
