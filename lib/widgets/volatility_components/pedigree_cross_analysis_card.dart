import 'package:flutter/material.dart';
import 'package:hetaumakeiba_v2/models/historical_match_model.dart';

class PedigreeCrossAnalysisCard extends StatelessWidget {
  final CrossAnalysisResult result;
  final VoidCallback? onFetchPedigree;
  final bool isFetching;
  final int currentFetchCount; // ★追加: 現在の取得件数
  final int totalFetchCount;   // ★追加: 全体の取得件数

  const PedigreeCrossAnalysisCard({
    super.key,
    required this.result,
    this.onFetchPedigree,
    this.isFetching = false,
    this.currentFetchCount = 0,
    this.totalFetchCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    // ★修正: データがない場合は取得ボタンを表示するカードを返す
    if (result.overallSires.isEmpty) {
      return Card(
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: SizedBox(
            width: double.infinity,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Text(
                  '好走血統 × 馬場状態 クロス分析',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                const Text(
                  '過去上位馬の血統データが不足しているため、分析を表示できません。',
                  style: TextStyle(fontSize: 13, color: Colors.grey),
                ),
                const SizedBox(height: 16),
                isFetching
                    ? Column(
                  children: [
                    SizedBox(
                      width: 200,
                      child: LinearProgressIndicator(
                        // totalFetchCountが0より大きい場合のみ割合を計算
                        value: totalFetchCount > 0 ? currentFetchCount / totalFetchCount : null,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '取得中... $currentFetchCount / $totalFetchCount 頭',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blue),
                    ),
                  ],
                )
                    : ElevatedButton.icon(
                  onPressed: onFetchPedigree,
                  icon: const Icon(Icons.download),
                  label: const Text('過去上位馬の血統情報を取得'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '好走血統 × 馬場状態 クロス分析 (3着内)',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            DefaultTabController(
              length: 3,
              child: Column(
                children: [
                  TabBar(
                    isScrollable: true,
                    labelColor: Colors.blue.shade800,
                    unselectedLabelColor: Colors.grey,
                    indicatorColor: Colors.blue.shade800,
                    tabs: const [
                      Tab(text: '全体傾向'),
                      Tab(text: 'クッション値別'),
                      Tab(text: '含水率別'),
                    ],
                  ),
                  SizedBox(
                    height: 250, // 高さを固定してスクロール可能に
                    child: TabBarView(
                      children: [
                        // 全体傾向タブ
                        _buildScrollableLists(
                          title1: '種牡馬 (父)', list1: result.overallSires,
                          title2: '母父 (BMS)', list2: result.overallBms,
                        ),
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
          ],
        ),
      ),
    );
  }

  // 2列並びのリスト（全体・含水率で使用）
  Widget _buildScrollableLists({
    required String title1, required List<PedigreeCount> list1,
    required String title2, required List<PedigreeCount> list2,
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
    required String title1, required List<PedigreeCount> list1,
    required String title2, required List<PedigreeCount> list2,
    required String title3, required List<PedigreeCount> list3,
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

  Widget _buildListColumn(String title, List<PedigreeCount> items) {
    // 1回しか馬券になっていない血統は省くか、上位5位までに絞る
    final displayItems = items.where((e) => e.count >= 1).take(5).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black54)),
        ),
        Expanded(
          child: displayItems.isEmpty
              ? const Text('-', style: TextStyle(color: Colors.grey))
              : ListView.builder(
            itemCount: displayItems.length,
            itemBuilder: (context, index) {
              final item = displayItems[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: 4.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(item.name, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                    Text('${item.count}回', style: const TextStyle(fontSize: 12, color: Colors.blue)),
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