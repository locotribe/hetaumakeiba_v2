// lib/widgets/volatility_analysis_tab.dart

import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart' as intl;
import 'package:hetaumakeiba_v2/db/repositories/race_repository.dart';
import 'package:hetaumakeiba_v2/models/race_result_model.dart';
import 'package:hetaumakeiba_v2/logic/ai/volatility_analyzer.dart';
import 'package:hetaumakeiba_v2/db/repositories/track_condition_repository.dart';
import 'package:hetaumakeiba_v2/models/track_conditions_model.dart';

class VolatilityAnalysisTab extends StatefulWidget {
  final List<String> targetRaceIds;

  const VolatilityAnalysisTab({Key? key, required this.targetRaceIds})
      : super(key: key);

  @override
  State<VolatilityAnalysisTab> createState() => _VolatilityAnalysisTabState();
}

class _VolatilityAnalysisTabState extends State<VolatilityAnalysisTab> {
  final RaceRepository _raceRepo = RaceRepository();
  final VolatilityAnalyzer _analyzer = VolatilityAnalyzer();
  bool _isLoading = true;

  VolatilityResult? _volatilityResult;
  PayoutAnalysisResult? _payoutResult;
  PopularityAnalysisResult? _popularityResult;
  FrameAnalysisResult? _frameResult;
  LegStyleAnalysisResult? _legStyleResult;
  HorseWeightAnalysisResult? _horseWeightResult;
  LapTimeAnalysisResult? _lapTimeResult; // ★追加: ラップタイム解析結果

  // ★追加: グラフのツールチップ固定表示用の状態変数
  int? _touchedBarIndex;
  int? _touchedSpotIndex;

  // ★追加: 過去の上位3頭と馬場状態を保持する変数
  List<PastRaceTop3Result>? _pastTop3Result;
  final Map<String, TrackConditionRecord> _trackConditionMap = {};

  @override
  void initState() {
    super.initState();
    _fetchAndAnalyze();
  }

  Future<void> _fetchAndAnalyze() async {
    List<RaceResult> pastRaces = [];
    final tcRepo = TrackConditionRepository();

    for (String id in widget.targetRaceIds) {
      final race = await _raceRepo.getRaceResult(id);
      if (race != null) pastRaces.add(race);

      // ★修正: レースIDから先頭10桁(プレフィックス)を切り出して当日の馬場状態を検索
      if (id.length >= 10) {
        String prefix10 = id.substring(0, 10);
        final tc = await tcRepo.getLatestTrackConditionByPrefix(prefix10);
        if (tc != null) {
          // UI側から呼び出しやすいように、キーは元のレースIDのままMapに保存する
          _trackConditionMap[id] = tc;
        }
      }
    }

    if (mounted) {
      setState(() {
        _volatilityResult = _analyzer.analyze(pastRaces);
        _payoutResult = PayoutAnalyzer().analyze(pastRaces);
        _popularityResult = PopularityAnalyzer().analyze(pastRaces);
        _frameResult = FrameAnalyzer().analyze(pastRaces);
        _legStyleResult = LegStyleAnalyzer().analyze(pastRaces);
        _horseWeightResult = HorseWeightAnalyzer().analyze(pastRaces);
        _pastTop3Result = PastTopHorsesAnalyzer().analyze(pastRaces);
        _lapTimeResult = LapTimeAnalyzer().analyze(pastRaces); // ★追加: ラップタイム解析の実行
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_volatilityResult == null) {
      return const Center(child: Text('データの分析に失敗しました。'));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildVolatilityCard(_volatilityResult!),
          const SizedBox(height: 16),
          _buildPastTopHorsesCard(), // ★ここに追加
          const SizedBox(height: 16),
          _buildPayoutComparisonCard(),
          const SizedBox(height: 16),
          _buildFrameChartCard(),
          const SizedBox(height: 16),
          _buildLegStyleChartCard(),
          const SizedBox(height: 16),
          _buildHorseWeightCard(),
          const SizedBox(height: 16),
          _buildLapTimeChartCard(), // ★追加: ラップタイム・ペース分析カード
          const SizedBox(height: 32), // 下部の余白
        ],
      ),
    );
  }

  // 1. 波乱度（既存のUIを維持）
  Widget _buildVolatilityCard(VolatilityResult res) {
    Color diagColor;
    IconData diagIcon;

    if (res.diagnosis == '大波乱') {
      diagColor = Colors.red;
      diagIcon = Icons.warning_amber_rounded;
    } else if (res.diagnosis == '堅い') {
      diagColor = Colors.blue;
      diagIcon = Icons.shield;
    } else {
      diagColor = Colors.green;
      diagIcon = Icons.balance;
    }

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(diagIcon, size: 48, color: diagColor),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '波乱度: ${res.diagnosis}',
                        style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: diagColor),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '上位馬平均人気: ${res.averagePopularity.toStringAsFixed(2)}番人気',
                        style: const TextStyle(
                            fontSize: 14, color: Colors.black87),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              '分析レポート',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              res.description,
              style: const TextStyle(fontSize: 14, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }


  // ★新規追加: 過去レース上位3頭と馬場状態のリストカード
  Widget _buildPastTopHorsesCard() {
    if (_pastTop3Result == null || _pastTop3Result!.isEmpty) return const SizedBox.shrink();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('過去の好走馬 ＆ 馬場状態 (上位3頭)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            ..._pastTop3Result!.map((res) {
              // 事前に取得しておいた馬場状態データ(クッション値・含水率)を取り出す
              final tc = _trackConditionMap[res.raceId];

              // レース情報文字列から「芝」か「ダート」かを判定
              bool isTurf = res.raceInfo.contains('芝') || res.raceInfo.contains('障');
              bool isDirt = res.raceInfo.contains('ダ');

              // ★追加: raceInfoから馬場状態（良・稍重・重・不良）を抽出
              String conditionLabel = "";
              if (res.raceInfo.contains('不良')) {
                conditionLabel = '不良';
              } else if (res.raceInfo.contains('稍重')) {
                conditionLabel = '稍重';
              } else if (res.raceInfo.contains('重')) {
                conditionLabel = '重';
              } else if (res.raceInfo.contains('良')) {
                conditionLabel = '良';
              }

              // 詳細データ(クッション値・含水率)が存在するかどうかの判定
              bool hasTcDataTurf = tc != null && (tc.cushionValue != null || tc.moistureTurfGoal != null || tc.moistureTurf4c != null);
              bool hasTcDataDirt = tc != null && (tc.moistureDirtGoal != null || tc.moistureDirt4c != null);

              // ★修正: 馬場状態(良など)が抽出できたか、または詳細データがあれば枠を表示する
              bool showConditionBox = conditionLabel.isNotEmpty || (isTurf && hasTcDataTurf) || (isDirt && hasTcDataDirt);

              return Container(
                margin: const EdgeInsets.only(bottom: 16.0),
                padding: const EdgeInsets.all(12.0),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8.0),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // --- 1. ヘッダー (年とレース名) ---
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(color: Colors.blueGrey, borderRadius: BorderRadius.circular(4)),
                          child: Text('${res.year}年', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                        ),
                        const SizedBox(width: 8),
                        Expanded(child: Text(res.raceName, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold))),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // --- 2. 馬場状態 (状態 ＋ クッション値・含水率) ---
                    if (showConditionBox)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4), border: Border.all(color: Colors.grey.shade300)),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // 芝レースの場合
                            if (isTurf)
                              Wrap(
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  // ★追加: 一番左に馬場状態(良/重など)のタグを表示
                                  if (conditionLabel.isNotEmpty)
                                    Container(
                                      width: 32, // ★追加: 最大2文字分として横幅を固定
                                      alignment: Alignment.center, // ★追加: 1文字(良/重)の時に中央揃えにする
                                      padding: const EdgeInsets.symmetric(vertical: 2), // 横のpaddingは外す
                                      margin: const EdgeInsets.only(right: 8),
                                      decoration: BoxDecoration(color: Colors.green.shade50, border: Border.all(color: Colors.green), borderRadius: BorderRadius.circular(2)),
                                      child: Text(conditionLabel, style: const TextStyle(fontSize: 13, color: Colors.green, fontWeight: FontWeight.bold)),
                                    ),
                                  // 詳細数値(クッション・含水率)
                                  if (hasTcDataTurf) ...[
                                    const Text('芝: ', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.green)),
                                    Text('ｸｯｼｮﾝ値 ${tc.cushionValue ?? "-"} / ', style: const TextStyle(fontSize: 11)),
                                    Text('含水率(G) ${tc.moistureTurfGoal ?? "-"}% (4C) ${tc.moistureTurf4c ?? "-"}%', style: const TextStyle(fontSize: 11)),
                                  ]
                                ],
                              ),
                            // ダートレースの場合
                            if (isDirt)
                              Padding(
                                padding: EdgeInsets.only(top: (isTurf && (conditionLabel.isNotEmpty || hasTcDataTurf)) ? 4.0 : 0.0),
                                child: Wrap(
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    // ★追加: 一番左に馬場状態(良/重など)のタグを表示
                                    if (conditionLabel.isNotEmpty)
                                      Container(
                                        width: 32, // ★追加: 最大2文字分として横幅を固定
                                        alignment: Alignment.center, // ★追加: 1文字(良/重)の時に中央揃えにする
                                        padding: const EdgeInsets.symmetric(vertical: 2), // 横のpaddingは外す
                                        margin: const EdgeInsets.only(right: 8),
                                        decoration: BoxDecoration(color: Colors.orange.shade50, border: Border.all(color: Colors.orange), borderRadius: BorderRadius.circular(2)),
                                        child: Text(conditionLabel, style: const TextStyle(fontSize: 10, color: Colors.orange, fontWeight: FontWeight.bold)),
                                      ),
                                    // 詳細数値(含水率)
                                    if (hasTcDataDirt) ...[
                                      const Text('ダート: ', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.orange)),
                                      Text('含水率(G) ${tc.moistureDirtGoal ?? "-"}% (4C) ${tc.moistureDirt4c ?? "-"}%', style: const TextStyle(fontSize: 11)),
                                    ]
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                    if (showConditionBox)
                      const SizedBox(height: 8),

                    // --- 3. 上位3頭のリスト ---
                    ...res.topHorses.map((h) {
                      Color rankColor = h.rank == 1 ? Colors.amber : (h.rank == 2 ? Colors.blueGrey : Colors.brown.shade400);
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2.0),
                        child: Row(
                          children: [
                            SizedBox(width: 24, child: Text('${h.rank}着', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: rankColor))),
                            const SizedBox(width: 8),
                            Container(
                              width: 20,
                              height: 20,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(border: Border.all(color: Colors.grey), borderRadius: BorderRadius.circular(2)),
                              child: Text(h.frameNumber, style: const TextStyle(fontSize: 10)),
                            ),
                            const SizedBox(width: 4),
                            Container(
                              width: 20,
                              height: 20,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(2)),
                              child: Text(h.horseNumber, style: const TextStyle(fontSize: 10)),
                            ),
                            const SizedBox(width: 8),
                            Expanded(child: Text(h.horseName, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis)),
                            Text('${h.popularity}番人気', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                          ],
                        ),
                      );
                    }).toList(),
                  ],
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }


  // 2. 配当比較（平均値 vs 中央値）
  Widget _buildPayoutComparisonCard() {
    if (_payoutResult == null || _payoutResult!.averages.isEmpty) return const SizedBox.shrink();

    // 全馬券種を定義（表示順序を固定）
    final targetTypes = ['単勝', '複勝', '枠連', '馬連', 'ワイド', '馬単', '3連複', '3連単'];

    List<BarChartGroupData> barGroups = [];
    int xIndex = 0;
    List<String> labels = [];

    // 最高/最低を保持するMap
    Map<String, int?> maxVals = {};
    Map<String, int?> minVals = {};

    // 数値フォーマッタ (intl パッケージを使用)
    final currencyFormatter = intl.NumberFormat.decimalPattern('ja');

    for (String label in targetTypes) {
      if (_payoutResult!.averages.containsKey(label)) {
        double avg = _payoutResult!.averages[label] ?? 0;
        double med = _payoutResult!.medians[label] ?? 0;

        labels.add(label);
        barGroups.add(
          BarChartGroupData(
            x: xIndex,
            barRods: [
              BarChartRodData(toY: avg, color: Colors.orange.shade300, width: 8, borderRadius: BorderRadius.circular(2)),
              BarChartRodData(toY: med, color: Colors.deepOrange, width: 8, borderRadius: BorderRadius.circular(2)),
            ],
          ),
        );

        // 最高・最低額の取得とMapへの保存
        final rawList = _payoutResult!.rawPayouts[label] ?? [];
        if (rawList.isNotEmpty) {
          maxVals[label] = rawList.reduce((a, b) => a > b ? a : b).toInt();
          minVals[label] = rawList.reduce((a, b) => a < b ? a : b).toInt();
        } else {
          maxVals[label] = null;
          minVals[label] = null;
        }
        xIndex++;
      }
    }

    if (barGroups.isEmpty) return const SizedBox.shrink();

    // 単位を短縮するフォーマット関数 (例: 15000 -> 1.5万)
    String formatShort(int? val) {
      if (val == null) return '-';
      if (val == 0) return '0';
      if (val >= 10000) {
        return '${(val / 10000).toStringAsFixed(1).replaceAll('.0', '')}万';
      }
      return currencyFormatter.format(val);
    }

    // タップで詳細額が浮かび上がるテキストセルを構築する関数
    Widget buildTapCell(String text, int? exactVal) {
      // 縦の高さを14pxに固定してズレを防ぐ
      Widget cellContent = SizedBox(
        height: 14,
        child: Center(
          child: Text(text, style: const TextStyle(fontSize: 9), maxLines: 1),
        ),
      );

      if (exactVal != null) {
        return Tooltip(
          message: '${currencyFormatter.format(exactVal)}円',
          triggerMode: TooltipTriggerMode.tap, // タップで表示
          preferBelow: false,
          decoration: BoxDecoration(
            color: Colors.black87.withOpacity(0.9),
            borderRadius: BorderRadius.circular(6),
          ),
          textStyle: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
          child: cellContent, // InkWell等を使わずTooltipのみでシンプルに判定
        );
      }
      return cellContent;
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('配当傾向 (平均値 vs 中央値)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Row(
              children: [
                Icon(Icons.square, color: Color(0xFFFFB74D), size: 12), SizedBox(width: 4), Text('平均値', style: TextStyle(fontSize: 11)),
                SizedBox(width: 16),
                Icon(Icons.square, color: Colors.deepOrange, size: 12), SizedBox(width: 4), Text('中央値 (実態)', style: TextStyle(fontSize: 11)),
              ],
            ),
            const SizedBox(height: 24),
            // ★Stackを使ってグラフと見出し(左側)を綺麗に合成する
            Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 24.0), // 左側の見出し用の余白を確保
                  child: SizedBox(
                    height: 250, // 3行ラベルが入るように高さを少し広げる
                    child: BarChart(
                      BarChartData(
                        barTouchData: BarTouchData(
                          touchTooltipData: BarTouchTooltipData(
                            getTooltipItem: (group, groupIndex, rod, rodIndex) {
                              return BarTooltipItem(
                                '${currencyFormatter.format(rod.toY.toInt())}円',
                                const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
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
                          // X軸のラベル領域を改造して3行のデータを表示する
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 52, // 3行分(14px × 3 + 余白)の高さを確保
                              getTitlesWidget: (value, meta) {
                                int idx = value.toInt();
                                if (idx >= 0 && idx < labels.length) {
                                  String L = labels[idx];
                                  return Padding(
                                    padding: const EdgeInsets.only(top: 8.0),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        // 1行目: 馬券名
                                        SizedBox(height: 14, child: Center(child: Text(L, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold)))),
                                        // 2行目: 最低額
                                        buildTapCell(formatShort(minVals[L]), minVals[L]),
                                        // 3行目: 最高額
                                        buildTapCell(formatShort(maxVals[L]), maxVals[L]),
                                      ],
                                    ),
                                  );
                                }
                                return const SizedBox.shrink();
                              },
                            ),
                          ),
                          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        ),
                      ),
                    ),
                  ),
                ),
                // 左下に固定で配置する「最低」「最高」の見出し
                Positioned(
                  left: 0,
                  bottom: 0,
                  child: Container(
                    height: 52, // X軸のラベル領域(reservedSize)と高さをピッタリ合わせる
                    padding: const EdgeInsets.only(top: 8.0),
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(height: 14), // 1行目(馬券名)の高さ分をスキップ
                        // 2行目
                        SizedBox(height: 14, child: Center(child: Text('最低', style: TextStyle(fontSize: 9, color: Colors.grey, fontWeight: FontWeight.bold)))),
                        // 3行目
                        SizedBox(height: 14, child: Center(child: Text('最高', style: TextStyle(fontSize: 9, color: Colors.grey, fontWeight: FontWeight.bold)))),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

// 3. 人気別成績チャート
  Widget _buildPopularityChartCard() {
    if (_popularityResult == null || _popularityResult!.totalCounts.isEmpty) {
      return const SizedBox.shrink();
    }

    List<BarChartGroupData> barGroups = [];
    for (int i = 1; i <= 5; i++) {
      // 勝数・連対数・複勝数をそれぞれ取得
      double win = (_popularityResult!.winCounts[i] ?? 0).toDouble();
      double place = (_popularityResult!.placeCounts[i] ?? 0).toDouble();
      double show = (_popularityResult!.showCounts[i] ?? 0).toDouble();

      barGroups.add(
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: win,
              color: Colors.amber, // 勝数: 金色
              width: 10,
              borderRadius: BorderRadius.circular(2),
            ),
            BarChartRodData(
              toY: place,
              color: Colors.blueGrey, // 連対数: 銀/青系
              width: 10,
              borderRadius: BorderRadius.circular(2),
            ),
            BarChartRodData(
              toY: show,
              color: Colors.brown.shade400, // 複勝数: 銅/茶系
              width: 10,
              borderRadius: BorderRadius.circular(2),
            ),
          ],
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('上位人気馬の信頼度 (1〜5番人気)',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            // 凡例（Legend） - 馬体重チャートと統一
            Wrap(
              spacing: 12,
              runSpacing: 4,
              children: [
                Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.square, color: Colors.amber, size: 12),
                  const SizedBox(width: 4),
                  const Text('勝数', style: TextStyle(fontSize: 11))
                ]),
                Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.square, color: Colors.blueGrey, size: 12),
                  const SizedBox(width: 4),
                  const Text('連対数(2着内)', style: TextStyle(fontSize: 11))
                ]),
                Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.square, color: Colors.brown.shade400, size: 12),
                  const SizedBox(width: 4),
                  const Text('複勝数(3着内)', style: TextStyle(fontSize: 11))
                ]),
              ],
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 200,
              child: BarChart(
                BarChartData(
                  // ツールチップ（タップ時の吹き出し）の設定
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
                        reservedSize: 42, // ラベルの高さスペースを確保（2行分）
                        getTitlesWidget: (value, meta) {
                          int pop = value.toInt();
                          if (pop >= 1 && pop <= 5) {
                            int total = _popularityResult!.totalCounts[pop] ?? 0;
                            // 人気順の下に括弧書きで出走数を表示
                            return Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: Text('$pop番人気\n($total頭)',
                                  style: const TextStyle(fontSize: 10),
                                  textAlign: TextAlign.center),
                            );
                          }
                          return const Text('');
                        },
                      ),
                    ),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

// 4. 枠番別成績チャート
  Widget _buildFrameChartCard() {
    if (_frameResult == null || _frameResult!.totalCounts.isEmpty) {
      return const SizedBox.shrink();
    }

    List<BarChartGroupData> barGroups = [];
    for (int i = 1; i <= 8; i++) {
      // 勝数・連対数・複勝数をそれぞれ取得
      double win = (_frameResult!.winCounts[i] ?? 0).toDouble();
      double place = (_frameResult!.placeCounts[i] ?? 0).toDouble();
      double show = (_frameResult!.showCounts[i] ?? 0).toDouble();

      barGroups.add(
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: win,
              color: Colors.amber, // 勝数: 金色
              width: 10,
              borderRadius: BorderRadius.circular(2),
            ),
            BarChartRodData(
              toY: place,
              color: Colors.blueGrey, // 連対数: 銀/青系
              width: 10,
              borderRadius: BorderRadius.circular(2),
            ),
            BarChartRodData(
              toY: show,
              color: Colors.brown.shade400, // 複勝数: 銅/茶系
              width: 10,
              borderRadius: BorderRadius.circular(2),
            ),
          ],
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('枠番別 有利不利 (1〜8枠)',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            // 凡例（Legend） - 他のグラフと統一
            Wrap(
              spacing: 12,
              runSpacing: 4,
              children: [
                Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.square, color: Colors.amber, size: 12),
                  const SizedBox(width: 4),
                  const Text('勝数', style: TextStyle(fontSize: 11))
                ]),
                Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.square, color: Colors.blueGrey, size: 12),
                  const SizedBox(width: 4),
                  const Text('連対数(2着内)', style: TextStyle(fontSize: 11))
                ]),
                Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.square, color: Colors.brown.shade400, size: 12),
                  const SizedBox(width: 4),
                  const Text('複勝数(3着内)', style: TextStyle(fontSize: 11))
                ]),
              ],
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 200,
              child: BarChart(
                BarChartData(
                  // ツールチップ（タップ時の吹き出し）の設定
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
                        reservedSize: 42, // ラベルの高さスペースを確保（2行分）
                        getTitlesWidget: (value, meta) {
                          int frame = value.toInt();
                          if (frame >= 1 && frame <= 8) {
                            int total = _frameResult!.totalCounts[frame] ?? 0;
                            // 枠番の下に括弧書きで出走数を表示
                            return Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: Text('$frame枠\n($total頭)',
                                  style: const TextStyle(fontSize: 10),
                                  textAlign: TextAlign.center),
                            );
                          }
                          return const Text('');
                        },
                      ),
                    ),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 5. 脚質シェアチャート（円グラフ）
  Widget _buildLegStyleChartCard() {
    if (_legStyleResult == null || _legStyleResult!.winCounts.isEmpty)
      return const SizedBox.shrink();

    final Map<String, Color> colorMap = {
      '逃げ・先行': Colors.redAccent,
      '差し': Colors.blueAccent,
      '追込': Colors.amber,
      '不明': Colors.grey,
    };

    List<PieChartSectionData> sections = [];
    _legStyleResult!.winCounts.forEach((style, count) {
      if (count > 0 && style != '不明') {
        sections.add(
          PieChartSectionData(
            color: colorMap[style] ?? Colors.grey,
            value: count.toDouble(),
            title: '$style\n$count勝',
            radius: 60,
            titleStyle: const TextStyle(
                fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
          ),
        );
      }
    });

    if (sections.isEmpty) return const SizedBox.shrink();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('脚質別 勝率シェア',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: PieChart(
                PieChartData(
                  sectionsSpace: 2,
                  centerSpaceRadius: 40,
                  sections: sections,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 6. 馬体重傾向
  Widget _buildHorseWeightCard() {
    if (_horseWeightResult == null ||
        _horseWeightResult!.winningWeights.isEmpty)
      return const SizedBox.shrink();

    final avg = _horseWeightResult!.averageWinningWeight;
    final median = _horseWeightResult!.medianWinningWeight;
    final min =
        _horseWeightResult!.winningWeights.reduce((a, b) => a < b ? a : b);
    final max =
        _horseWeightResult!.winningWeights.reduce((a, b) => a > b ? a : b);

    // グラフ用データの構築
    List<BarChartGroupData> barGroups = [];
    final categories = ['-10kg以下', '-4~-8kg', '-2~+2kg', '+4~+8kg', '+10kg以上'];
    int xIndex = 0;

    for (String cat in categories) {
      final stats = _horseWeightResult!.changeStats[cat];
      if (stats != null) {
        barGroups.add(
          BarChartGroupData(
            x: xIndex,
            barRods: [
              BarChartRodData(
                toY: stats.win.toDouble(),
                color: Colors.amber, // 勝数: 金色
                width: 10,
                borderRadius: BorderRadius.circular(2),
              ),
              BarChartRodData(
                toY: stats.place.toDouble(),
                color: Colors.blueGrey, // 連対数: 銀/青系
                width: 10,
                borderRadius: BorderRadius.circular(2),
              ),
              BarChartRodData(
                toY: stats.show.toDouble(),
                color: Colors.brown.shade400, // 複勝数: 銅/茶系
                width: 10,
                borderRadius: BorderRadius.circular(2),
              ),
            ],
          ),
        );
      }
      xIndex++;
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
                      style:
                          const TextStyle(fontSize: 14, color: Colors.black87)),
                ],
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(
                    '範囲: ${min.toStringAsFixed(0)}kg 〜 ${max.toStringAsFixed(0)}kg'),
              ),
            ),
            const Divider(height: 32),
            const Text('馬体重増減別 実績',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            // 凡例（Legend）
            Wrap(
              spacing: 12,
              runSpacing: 4,
              children: [
                Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.square, color: Colors.amber, size: 12),
                  const SizedBox(width: 4),
                  const Text('勝数', style: TextStyle(fontSize: 11))
                ]),
                Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.square, color: Colors.blueGrey, size: 12),
                  const SizedBox(width: 4),
                  const Text('連対数(2着内)', style: TextStyle(fontSize: 11))
                ]),
                Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.square, color: Colors.brown.shade400, size: 12),
                  const SizedBox(width: 4),
                  const Text('複勝数(3着内)', style: TextStyle(fontSize: 11))
                ]),
              ],
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 180,
              child: BarChart(
                BarChartData(
                  barTouchData: BarTouchData(
                    touchTooltipData: BarTouchTooltipData(
                      // 背景色は tooltipBgColor ではなく getTooltipColor で指定する仕様、
                      // もしくはデフォルトを使用するために一旦指定を外します。
                      getTooltipItem: (group, groupIndex, rod, rodIndex) {
                        return BarTooltipItem(
                          '${rod.toY.toInt()}',
                          const TextStyle(
                            color: Colors.white, // ← 文字色を白に統一
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
                        reservedSize: 42, // ラベルの高さスペースを確保
                        getTitlesWidget: (value, meta) {
                          if (value.toInt() >= 0 &&
                              value.toInt() < categories.length) {
                            String cat = categories[value.toInt()];
                            int total =
                                _horseWeightResult!.changeStats[cat]?.total ??
                                    0;

                            // カテゴリー名の下に出走数を表示
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
                    topTitles:
                        AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles:
                        AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  // 7. ラップタイム・ペース分析カード
  Widget _buildLapTimeChartCard() {
    if (_lapTimeResult == null || _lapTimeResult!.averageLapTimes.isEmpty) {
      return const SizedBox.shrink();
    }

    String formatTime(double sec) {
      if (sec >= 60) {
        int m = (sec / 60).floor();
        double s = sec % 60;
        return '$m:${s.toStringAsFixed(1).padLeft(4, '0')}';
      }
      return '${sec.toStringAsFixed(1)}秒';
    }

    final avgLaps = _lapTimeResult!.averageLapTimes;

    double realMinY = 999.0;
    double realMaxY = 0.0;
    for (final race in _lapTimeResult!.allRacesLapData) {
      for (final lap in race.lapTimes) {
        if (lap < realMinY) realMinY = lap;
        if (lap > realMaxY) realMaxY = lap;
      }
    }
    for (final lap in avgLaps) {
      if (lap < realMinY) realMinY = lap;
      if (lap > realMaxY) realMaxY = lap;
    }
    realMinY = (realMinY - 0.5).floorToDouble();
    realMaxY = (realMaxY + 0.5).ceilToDouble();

    double chartMinY = -realMaxY;
    double chartMaxY = -realMinY;

    final avgSpots = <FlSpot>[];
    for (int i = 0; i < avgLaps.length; i++) {
      avgSpots.add(FlSpot(i.toDouble(), -avgLaps[i]));
    }

    final lineBars = <LineChartBarData>[];

    for (final race in _lapTimeResult!.allRacesLapData) {
      final raceSpots = <FlSpot>[];
      for (int i = 0; i < race.lapTimes.length; i++) {
        raceSpots.add(FlSpot(i.toDouble(), -race.lapTimes[i]));
      }

      Color lineColor;
      switch (race.trackCondition) {
        case '良':
          lineColor = Colors.green;
          break;
        case '稍重':
          lineColor = Colors.lightBlue;
          break;
        case '重':
          lineColor = Colors.brown;
          break;
        case '不良':
          lineColor = Colors.grey;
          break;
        default:
          lineColor = Colors.grey;
      }

      lineBars.add(
        LineChartBarData(
          spots: raceSpots,
          isCurved: true,
          color: lineColor.withOpacity(0.6),
          barWidth: 1.5,
          dotData: const FlDotData(show: false),
          showingIndicators: _touchedSpotIndex != null ? [_touchedSpotIndex!] : [],
        ),
      );
    }

    lineBars.add(
      LineChartBarData(
        spots: avgSpots,
        isCurved: true,
        color: Colors.red,
        barWidth: 3,
        isStrokeCapRound: true,
        dashArray: [5, 5],
        dotData: const FlDotData(show: true),
        showingIndicators: _touchedSpotIndex != null ? [_touchedSpotIndex!] : [],
      ),
    );

    List<DataRow> paceRows = [];
    _lapTimeResult!.paceLegStyleStats.forEach((pace, stats) {
      if (stats.total > 0) {
        double nige = (stats.showCounts['逃げ'] ?? 0) / stats.total * 100;
        double senkou = (stats.showCounts['先行'] ?? 0) / stats.total * 100;
        double sashi = (stats.showCounts['差し'] ?? 0) / stats.total * 100;
        double oikomi = (stats.showCounts['追込'] ?? 0) / stats.total * 100;
        paceRows.add(DataRow(cells: [
          DataCell(Text('$pace\n(${stats.total}回)', style: const TextStyle(fontSize: 11))),
          DataCell(Text('${nige.toStringAsFixed(1)}%', style: const TextStyle(fontSize: 12))),
          DataCell(Text('${senkou.toStringAsFixed(1)}%', style: const TextStyle(fontSize: 12))),
          DataCell(Text('${sashi.toStringAsFixed(1)}%', style: const TextStyle(fontSize: 12))),
          DataCell(Text('${oikomi.toStringAsFixed(1)}%', style: const TextStyle(fontSize: 12))),
        ]));
      }
    });

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('ラップタイム・ペース分析', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('過去の典型ペース: ${_lapTimeResult!.typicalPace}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.deepOrange)),
                  const SizedBox(height: 4),
                  Text('平均 前半3F: ${_lapTimeResult!.averageFirst3F.toStringAsFixed(1)}秒 / 後半3F: ${_lapTimeResult!.averageLast3F.toStringAsFixed(1)}秒', style: const TextStyle(fontSize: 13, color: Colors.black87)),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const Text('平均ラップ ＆ 個別ラップ推移', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              runSpacing: 4,
              children: [
                Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.remove, color: Colors.red, size: 16),
                  const SizedBox(width: 4),
                  const Text('平均ラップ', style: TextStyle(fontSize: 11))
                ]),
                Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.remove, color: Colors.green, size: 16),
                  const SizedBox(width: 4),
                  const Text('良', style: TextStyle(fontSize: 11))
                ]),
                Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.remove, color: Colors.lightBlue, size: 16),
                  const SizedBox(width: 4),
                  const Text('稍重', style: TextStyle(fontSize: 11))
                ]),
                Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.remove, color: Colors.brown, size: 16),
                  const SizedBox(width: 4),
                  const Text('重', style: TextStyle(fontSize: 11))
                ]),
                Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.remove, color: Colors.grey, size: 16),
                  const SizedBox(width: 4),
                  const Text('不良', style: TextStyle(fontSize: 11))
                ]),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 250,
              child: LineChart(
                LineChartData(
                  minY: chartMinY,
                  maxY: chartMaxY,
                  gridData: const FlGridData(show: true, drawVerticalLine: true, drawHorizontalLine: true),
                  titlesData: FlTitlesData(
                    show: true,
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 22,
                        interval: 1.0,
                        getTitlesWidget: (value, meta) {
                          if (value % 1 != 0) return const SizedBox.shrink();
                          int idx = value.toInt();
                          if (idx >= 0 && idx < avgLaps.length) {
                            return Text('${idx + 1}F', style: const TextStyle(fontSize: 10));
                          }
                          return const Text('');
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 32,
                        getTitlesWidget: (value, meta) {
                          return Text(value.abs().toStringAsFixed(1), style: const TextStyle(fontSize: 10));
                        },
                      ),
                    ),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(show: true, border: Border.all(color: Colors.grey.shade300)),
                  lineBarsData: lineBars,
                  lineTouchData: LineTouchData(
                    handleBuiltInTouches: false,
                    touchCallback: (FlTouchEvent event, LineTouchResponse? response) {
                      if (!event.isInterestedForInteractions) return;

                      if (event is FlTapDownEvent) {
                        if (response != null && response.lineBarSpots != null && response.lineBarSpots!.isNotEmpty) {
                          final spot = response.lineBarSpots!.first;
                          setState(() {
                            if (_touchedSpotIndex == spot.spotIndex) {
                              _touchedSpotIndex = null;
                            } else {
                              _touchedSpotIndex = spot.spotIndex;
                            }
                          });
                        } else {
                          setState(() {
                            _touchedSpotIndex = null;
                          });
                        }
                      }
                    },
                    touchTooltipData: LineTouchTooltipData(
                      getTooltipColor: (touchedSpot) => Colors.transparent,
                      tooltipPadding: EdgeInsets.zero,
                      tooltipMargin: 0,
                      getTooltipItems: (touchedSpots) {
                        return touchedSpots.map((spot) => const LineTooltipItem('', TextStyle(fontSize: 0))).toList();
                      },
                    ),
                  ),
                ),
              ),
            ),

            // ★修正: グラフの下に出現する「詳細パネル」（ソート・色合わせ対応）
            if (_touchedSpotIndex != null) ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Builder(
                    builder: (context) {
                      List<Map<String, dynamic>> panelData = [];

                      // 1. 平均データの計算とリスト追加
                      if (_touchedSpotIndex! < avgLaps.length) {
                        double avgCum = 0;
                        for (int i = 0; i <= _touchedSpotIndex!; i++) {
                          avgCum += avgLaps[i];
                        }
                        panelData.add({
                          'isAverage': true,
                          'title': '平均',
                          'cum': avgCum,
                          'lap': avgLaps[_touchedSpotIndex!],
                          'color': Colors.red,
                        });
                      }

                      // 2. 各レースデータの計算とリスト追加
                      for (final race in _lapTimeResult!.allRacesLapData) {
                        if (_touchedSpotIndex! >= race.lapTimes.length) continue;

                        double cum = 0;
                        for (int i = 0; i <= _touchedSpotIndex!; i++) {
                          cum += race.lapTimes[i];
                        }

                        Color textColor;
                        switch (race.trackCondition) {
                          case '良': textColor = Colors.green; break;
                          case '稍重': textColor = Colors.lightBlue; break;
                          case '重': textColor = Colors.brown; break;
                          case '不良': textColor = Colors.grey; break;
                          default: textColor = Colors.grey;
                        }

                        // 年のみの抽出 ("2023年5月24日" -> "2023年")
                        String yearStr = race.raceDate;
                        if (yearStr.contains('年')) {
                          yearStr = yearStr.substring(0, yearStr.indexOf('年') + 1);
                        }

                        bool isGoal = _touchedSpotIndex! == race.lapTimes.length - 1;

                        panelData.add({
                          'isAverage': false,
                          'title': yearStr,
                          'cum': cum,
                          'lap': race.lapTimes[_touchedSpotIndex!],
                          'color': textColor,
                          'isGoal': isGoal,
                          'winningHorseName': race.winningHorseName,
                          'last3F': race.last3F,
                        });
                      }

                      // 3. 通過タイム(cum)が早い順にソート（グラフの上下とシンクロさせる）
                      panelData.sort((a, b) => (a['cum'] as double).compareTo(b['cum'] as double));

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${_touchedSpotIndex! + 1}F目 通過詳細 (早い順)', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.blueAccent)),
                          const SizedBox(height: 12),
                          ...panelData.map((data) {
                            final bool isAverage = data['isAverage'];
                            final Color color = data['color'];
                            final String title = data['title'];
                            final double cum = data['cum'];
                            final double lap = data['lap'];

                            if (isAverage) {
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 6.0),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      flex: 2,
                                      child: Text(title, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color)),
                                    ),
                                    Expanded(
                                      flex: 3,
                                      child: Text('通過: ${formatTime(cum)} / 区間: ${lap.toStringAsFixed(1)}秒', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color)),
                                    ),
                                  ],
                                ),
                              );
                            } else {
                              final bool isGoal = data['isGoal'];
                              final String winningHorseName = data['winningHorseName'];
                              final double last3F = data['last3F'];

                              return Padding(
                                padding: const EdgeInsets.only(bottom: 6.0),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      flex: 2,
                                      child: Text(
                                        isGoal ? '$title\n(ゴール)' : title,
                                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 3,
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text('通過: ${formatTime(cum)} / 区間: ${lap.toStringAsFixed(1)}秒', style: TextStyle(fontSize: 11, color: color)),
                                          // アイコンを削除してシンプルに表示
                                          if (isGoal) Text('$winningHorseName / 上がり: ${last3F.toStringAsFixed(1)}秒', style: TextStyle(fontSize: 11, color: color.withOpacity(0.8))),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }
                          }).toList(),
                        ],
                      );
                    }
                ),
              ),
            ],

            const SizedBox(height: 24),
            const Text('ペース別 脚質好走率 (3着内シェア)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columnSpacing: 16,
                headingRowHeight: 40,
                dataRowMinHeight: 48,
                dataRowMaxHeight: 48,
                columns: const [
                  DataColumn(label: Text('ペース')),
                  DataColumn(label: Text('逃げ')),
                  DataColumn(label: Text('先行')),
                  DataColumn(label: Text('差し')),
                  DataColumn(label: Text('追込')),
                ],
                rows: paceRows,
              ),
            ),
            if (_lapTimeResult!.acceleratingRaces.isNotEmpty) ...[
              const SizedBox(height: 24),
              const Text('加速ラップ記録レース (終盤失速なし)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              ..._lapTimeResult!.acceleratingRaces.map((r) => ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.speed, color: Colors.green),
                title: Text(r.raceName, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                subtitle: Text('前3F: ${r.first3F.toStringAsFixed(1)}秒 / 後3F: ${r.last3F.toStringAsFixed(1)}秒', style: const TextStyle(fontSize: 11)),
              )),
            ]
          ],
        ),
      ),
    );
  }
}
