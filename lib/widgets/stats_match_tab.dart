// lib/widgets/stats_match_tab.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:hetaumakeiba_v2/db/repositories/race_repository.dart';
import 'package:hetaumakeiba_v2/db/repositories/horse_repository.dart';
import 'package:hetaumakeiba_v2/models/ai_prediction_race_data.dart';
import 'package:hetaumakeiba_v2/models/race_result_model.dart';
import 'package:hetaumakeiba_v2/models/historical_match_model.dart';
import 'package:hetaumakeiba_v2/models/horse_performance_model.dart';
import 'package:hetaumakeiba_v2/services/historical_match_service.dart';
import 'package:hetaumakeiba_v2/logic/ai/historical_match_engine.dart';
import 'package:hetaumakeiba_v2/logic/ai/volatility_analyzer.dart';

// 類似度データを保持するクラス
class SimilarityData {
  final String horseName;
  final double similarity; // 0-100
  final String rank;
  final String popularity;
  final String raceName;
  final String raceDate;

  SimilarityData({
    required this.horseName,
    required this.similarity,
    required this.rank,
    required this.popularity,
    required this.raceName,
    required this.raceDate,
  });
}

class StatsMatchTab extends StatefulWidget {
  final String raceId;
  final String raceName;
  final List<PredictionHorseDetail> horses;
  // 集計対象とするレースIDのリスト
  final List<String>? targetRaceIds;
  // 比較対象（予想時）のデータリスト。これがある場合は結果分析モードとして動作
  final List<PredictionHorseDetail>? comparisonTargets;

  const StatsMatchTab({
    super.key,
    required this.raceId,
    required this.raceName,
    required this.horses,
    this.targetRaceIds,
    this.comparisonTargets,
  });

  @override
  State<StatsMatchTab> createState() => _StatsMatchTabState();
}

class _StatsMatchTabState extends State<StatsMatchTab> {
  final HistoricalMatchService _service = HistoricalMatchService();
  final HistoricalMatchEngine _engine = HistoricalMatchEngine();
  final RaceRepository _raceRepo = RaceRepository();
  final HorseRepository _horseRepo = HorseRepository();

  bool _isLoading = true;
  String _statusMessage = 'データ準備中...';
  List<HistoricalMatchModel> _results = [];
  // 予想データの分析結果を保持するマップ (Key: horseId)
  Map<String, HistoricalMatchModel> _predictionResultMap = {};
  TrendSummary? _summary;
  String? _errorMessage;

  // 類似度分析の結果保持用
  Map<String, List<SimilarityData>> _similarityAllMatches = {};
  Map<String, SimilarityData?> _similarityBestFirstPlace = {};

  @override
  void initState() {
    super.initState();
    _startAnalysis();
  }

  Future<void> _startAnalysis() async {
    try {
      if (mounted) setState(() => _statusMessage = '詳細データを収集中...');

      // 1. 今回の出走馬の履歴を取得
      final Map<String, List<HorseRaceRecord>> currentHorseHistory = {};
      for (final horse in widget.horses) {
        final records = await _horseRepo.getHorsePerformanceRecords(horse.horseId);
        currentHorseHistory[horse.horseId] = records;
      }

      // 2. 過去レース情報を取得（比較対象のレース群）
      List<RaceResult> pastRaces;
      if (widget.targetRaceIds != null && widget.targetRaceIds!.isNotEmpty) {
        final resultsMap = await _raceRepo.getMultipleRaceResults(widget.targetRaceIds!);
        pastRaces = resultsMap.values.toList();
      } else {
        pastRaces = await _raceRepo.searchRaceResultsByName(widget.raceName);
      }

      // データがない場合の早期リターン
      if (pastRaces.isEmpty) {
        if (mounted) {
          setState(() {
            _results = [];
            _isLoading = false;
          });
        }
        return;
      }

      // 3. 過去の上位馬の履歴を取得
      setState(() => _statusMessage = '過去の好走パターンを分析中...');
      final Map<String, List<HorseRaceRecord>> pastTopHorseRecords = {};

      for (final race in pastRaces) {
        for (final horse in race.horseResults) {
          final rank = int.tryParse(horse.rank ?? '');
          if (rank != null && rank <= 3 && horse.horseId.isNotEmpty) {
            if (!pastTopHorseRecords.containsKey(horse.horseId)) {
              final records = await _horseRepo.getHorsePerformanceRecords(horse.horseId);
              pastTopHorseRecords[horse.horseId] = records;
            }
          }
        }
      }

      // 4. 類似度分析ロジックの実行
      final Map<String, List<SimilarityData>> tempSimilarityAllMatches = {};
      final Map<String, SimilarityData?> tempSimilarityBestFirstPlace = {};

      // 基準日を「対象レースの開催日」にする
      String targetRaceDateStr;

      // まず結果データ(RaceResult)から日付を探す
      final targetResult = await _raceRepo.getRaceResult(widget.raceId);
      if (targetResult != null) {
        targetRaceDateStr = targetResult.raceDate;
      } else {
        // なければ出馬表キャッシュ(ShutubaTableCache)から日付を探す
        final targetCache = await _raceRepo.getShutubaTableCache(widget.raceId);
        if (targetCache != null) {
          targetRaceDateStr = targetCache.predictionRaceData.raceDate;
        } else {
          // それでもなければ（稀なケース）、今日の日付をフォールバックとして使う
          targetRaceDateStr = DateFormat('yyyy/MM/dd').format(DateTime.now());
        }
      }

      for (final currentHorse in widget.horses) {
        List<SimilarityData> matches = [];
        SimilarityData? bestFirstPlaceMatch;
        double bestFirstPlaceScore = -1.0;

        // 今回の馬の前走レース名を取得（対象レースの日付を基準にする）
        final curHistory = currentHorseHistory[currentHorse.horseId];
        final curPrevRaceName = _getPreviousRaceName(curHistory, targetRaceDateStr);

        for (final race in pastRaces) {
          for (final pastHorse in race.horseResults) {
            // 過去馬の前走レース名を取得（その過去レースの日付を基準にする）
            final pastHistory = pastTopHorseRecords[pastHorse.horseId];
            final pastPrevRaceName = _getPreviousRaceName(pastHistory, race.raceDate);

            // 類似度計算
            final score = _calculateSimilarity(
              currentHorse,
              pastHorse,
              curPrevRaceName,
              pastPrevRaceName,
            );

            // 1着馬の中でベストスコアを探す
            if (pastHorse.rank == '1') {
              if (score > bestFirstPlaceScore) {
                bestFirstPlaceScore = score;
                bestFirstPlaceMatch = SimilarityData(
                  horseName: pastHorse.horseName,
                  similarity: score,
                  rank: pastHorse.rank,
                  popularity: pastHorse.popularity,
                  raceName: race.raceTitle,
                  raceDate: race.raceDate,
                );
              }
            }

            // 50%以上ならリストに追加
            if (score >= 50.0) {
              matches.add(SimilarityData(
                horseName: pastHorse.horseName,
                similarity: score,
                rank: pastHorse.rank,
                popularity: pastHorse.popularity,
                raceName: race.raceTitle,
                raceDate: race.raceDate,
              ));
            }
          }
        }

        // 類似度順にソート
        matches.sort((a, b) => b.similarity.compareTo(a.similarity));

        tempSimilarityAllMatches[currentHorse.horseId] = matches;

        if (bestFirstPlaceScore < 50.0) {
          tempSimilarityBestFirstPlace[currentHorse.horseId] = null;
        } else {
          tempSimilarityBestFirstPlace[currentHorse.horseId] = bestFirstPlaceMatch;
        }
      }

      final volatilityAnalyzer = VolatilityAnalyzer();
      final volResult = volatilityAnalyzer.analyze(pastRaces);

      // 5. HistoricalMatchEngineによる分析
      final analysisResult = _engine.analyze(
        currentRaceName: widget.raceName,
        pastRaceVolatility: volResult.averagePopularity,
        currentHorses: widget.horses,
        pastRaces: pastRaces,
        currentHorseHistory: currentHorseHistory,
        pastTopHorseRecords: pastTopHorseRecords,
      );

      // 比較対象(予想データ)の分析
      if (widget.comparisonTargets != null && widget.comparisonTargets!.isNotEmpty) {
        final predictionAnalysis = _engine.analyze(
          currentRaceName: widget.raceName,
          pastRaceVolatility: volResult.averagePopularity,
          currentHorses: widget.comparisonTargets!,
          pastRaces: pastRaces,
          currentHorseHistory: currentHorseHistory,
          pastTopHorseRecords: pastTopHorseRecords,
        );
        final predList = predictionAnalysis['results'] as List<HistoricalMatchModel>;
        _predictionResultMap = {for (var e in predList) e.horseId: e};
      } else {
        _predictionResultMap.clear();
      }

      if (mounted) {
        setState(() {
          _results = analysisResult['results'] as List<HistoricalMatchModel>;
          _summary = analysisResult['summary'] as TrendSummary?;
          _similarityAllMatches = tempSimilarityAllMatches;
          _similarityBestFirstPlace = tempSimilarityBestFirstPlace;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = '分析中にエラーが発生しました:\n$e';
        });
      }
    }
  }

  /// 類似度計算メソッド
  /// 要素: 性齢, 馬体重, 斤量, ローテーション(レース名一致)
  double _calculateSimilarity(
      PredictionHorseDetail current,
      HorseResult past,
      String? curPrevRaceName,
      String? pastPrevRaceName,
      ) {
    double totalScore = 0;
    int count = 0;

    // 1. 性齢
    final curSex = current.sexAndAge.isNotEmpty ? current.sexAndAge.substring(0, 1) : '';
    final pastSex = past.sexAndAge.isNotEmpty ? past.sexAndAge.substring(0, 1) : '';
    if (curSex.isNotEmpty && pastSex.isNotEmpty) {
      if (curSex == pastSex) totalScore += 100;
      count++;
    }

    final curAge = int.tryParse(current.sexAndAge.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
    final pastAge = int.tryParse(past.sexAndAge.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
    if (curAge > 0 && pastAge > 0) {
      final diff = (curAge - pastAge).abs();
      double score = 0;
      if (diff == 0) score = 100;
      else if (diff == 1) score = 80;
      else if (diff == 2) score = 50;
      totalScore += score;
      count++;
    }

    // 2. 馬体重
    final curWeightStr = current.horseWeight?.split('(').first ?? '';
    final pastWeightStr = past.horseWeight.split('(').first;
    final curWeight = int.tryParse(curWeightStr) ?? 0;
    final pastWeight = int.tryParse(pastWeightStr) ?? 0;
    if (curWeight > 0 && pastWeight > 0) {
      final diff = (curWeight - pastWeight).abs();
      double score = 100 - (diff * 2.5);
      totalScore += score < 0 ? 0 : score;
      count++;
    }

    // 3. 斤量
    final pastCarried = double.tryParse(past.weightCarried) ?? 0.0;
    if (current.carriedWeight > 0 && pastCarried > 0) {
      final diff = (current.carriedWeight - pastCarried).abs();
      double score = 100 - (diff * 15);
      totalScore += score < 0 ? 0 : score;
      count++;
    }

    // 4. ローテーション (レース名)
    if (curPrevRaceName != null && pastPrevRaceName != null && curPrevRaceName.isNotEmpty && pastPrevRaceName.isNotEmpty) {
      // 文字列の部分一致判定
      if (curPrevRaceName.contains(pastPrevRaceName) || pastPrevRaceName.contains(curPrevRaceName)) {
        totalScore += 100;
      } else {
        totalScore += 0;
      }
      count++;
    }

    if (count == 0) return 0.0;
    return totalScore / count;
  }

  // --- 以下、ヘルパー ---

  /// 文字列日付をDateTimeに変換 (ソート用に使用)
  DateTime? _parseDate(String dateStr) {
    try {
      // "2023年10月24日" 形式
      if (dateStr.contains('年')) {
        return DateFormat('yyyy年M月d日').parse(dateStr);
      }
      // "2023/10/24" 形式
      if (dateStr.contains('/')) {
        return DateFormat('yyyy/MM/dd').parse(dateStr);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// 指定された基準日より「前」の最新のレース名を取得
  String? _getPreviousRaceName(List<HorseRaceRecord>? history, String referenceDateStr) {
    if (history == null || history.isEmpty) return null;

    final referenceDate = _parseDate(referenceDateStr);
    if (referenceDate == null) return null;

    // 履歴を日付降順（新しい順）にソート
    final sortedHistory = List<HorseRaceRecord>.from(history);
    sortedHistory.sort((a, b) {
      final da = _parseDate(a.date) ?? DateTime(1900);
      final db = _parseDate(b.date) ?? DateTime(1900);
      return db.compareTo(da);
    });

    // 基準日より前にある最初のレコードを探す
    for (final record in sortedHistory) {
      final recDate = _parseDate(record.date);
      if (recDate != null && recDate.isBefore(referenceDate)) {
        return record.raceName;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const CircularProgressIndicator(),
        const SizedBox(height: 16),
        Text(_statusMessage, style: const TextStyle(color: Colors.grey)),
      ]));
    }
    if (_errorMessage != null) {
      return Center(child: Text(_errorMessage!, style: const TextStyle(color: Colors.red)));
    }
    if (_results.isEmpty) {
      return const Center(child: Text('該当する過去レースデータがありませんでした。'));
    }

    return Column(
      children: [
        if (_summary != null) _buildTrendHeader(_summary!),
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.vertical,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: _buildResultTable(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTrendHeader(TrendSummary summary) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      color: Colors.grey[200],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('【過去の傾向分析】', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Wrap(
            spacing: 12,
            runSpacing: 4,
            children: [
              _headerItem(Icons.monitor_weight_outlined, '基準:${summary.medianWeight.toStringAsFixed(0)}kg'),
              _headerItem(Icons.view_column_outlined, '有利:${summary.bestZone}'),
              _headerItem(Icons.loop, 'ローテ:${summary.bestRotation}'),
              _headerItem(Icons.trending_up, '前走人気:${summary.bestPrevPop}'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _headerItem(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: Colors.blueGrey),
        const SizedBox(width: 2),
        Text(text, style: const TextStyle(fontSize: 12)),
      ],
    );
  }

  Widget _buildResultTable() {
    double maxScore = 0.0;
    if (_results.isNotEmpty) {
      maxScore = _results.map((e) => e.totalScore).reduce((a, b) => a > b ? a : b);
    }

    // 比較モードかどうか
    final isComparisonMode = widget.comparisonTargets != null;

    return DataTable(
      headingRowColor: MaterialStateProperty.all(Colors.grey[100]),
      columnSpacing: 20,
      columns: [
        if (isComparisonMode) const DataColumn(label: Text('着順/印')),
        const DataColumn(label: Text('馬名')),
        const DataColumn(label: Text('類似馬(1着)')),
        const DataColumn(label: Text('総合シンクロ')),
        const DataColumn(label: Text('人気妙味')),
        const DataColumn(label: Text('信頼度(格)')),
        const DataColumn(label: Text('馬体重')),
        const DataColumn(label: Text('枠順')),
      ],
      rows: _results.map((item) {
        // 予想データの対応データを取得
        final predictionItem = _predictionResultMap[item.horseId];

        // 予想データから印を取得
        String? userMark;
        if (isComparisonMode && widget.comparisonTargets != null) {
          final target = widget.comparisonTargets!.firstWhere(
                  (h) => h.horseId == item.horseId,
              orElse: () => widget.comparisonTargets![0] // ダミー
          );
          if (target.horseId == item.horseId) {
            userMark = target.userMark?.mark;
          }
        }

        // 着順データの取得
        String? rankStr;
        if (isComparisonMode) {
          final currentHorse = widget.horses.firstWhere((h) => h.horseId == item.horseId, orElse: () => widget.horses[0]);
          if (currentHorse.horseId == item.horseId) {
            rankStr = currentHorse.popularity != null ? '${currentHorse.popularity}着' : '-';
          }
        }

        return DataRow(cells: [
          if (isComparisonMode)
            DataCell(Row(
              children: [
                if (rankStr != null)
                  Text(rankStr, style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(width: 4),
                if (userMark != null)
                  Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _getMarkColor(userMark),
                    ),
                    child: Text(userMark, style: const TextStyle(color: Colors.white, fontSize: 10)),
                  ),
              ],
            )),
          DataCell(Text(item.horseName, style: const TextStyle(fontWeight: FontWeight.bold))),
          // 類似馬(1着)セル
          DataCell(_buildSimilarityCell(item.horseId, item.horseName)),

          DataCell(_buildTotalScoreCell(item.totalScore, maxScore, predictionItem?.totalScore)),
          DataCell(InkWell(
            onTap: () => _showPopularityDetailDialog(context, item),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
              child: _buildPopularityCell(item),
            ),
          )),
          DataCell(_buildRotationCell(item)),
          DataCell(_buildWeightDetailCell(item, predictionItem)),
          DataCell(_buildFrameDetailCell(item)),
        ]);
      }).toList(),
    );
  }

  // 類似馬セル構築
  Widget _buildSimilarityCell(String horseId, String horseName) {
    final bestMatch = _similarityBestFirstPlace[horseId];

    // 50%以上の1着馬がいない場合
    if (bestMatch == null) {
      return InkWell(
        onTap: () => _showSimilarityDetailDialog(context, horseName, horseId),
        child: const Text('該当なし', style: TextStyle(color: Colors.grey, fontSize: 12)),
      );
    }

    return InkWell(
      onTap: () => _showSimilarityDetailDialog(context, horseName, horseId),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(bestMatch.horseName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.blue)),
          Text('類似度:${bestMatch.similarity.toStringAsFixed(0)}%', style: const TextStyle(fontSize: 11, color: Colors.black54)),
        ],
      ),
    );
  }

  // 類似度詳細ダイアログ
  void _showSimilarityDetailDialog(BuildContext context, String horseName, String horseId) {
    final matches = _similarityAllMatches[horseId] ?? [];

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('$horseName の類似馬分析\n(類似度50%以上)', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          content: SizedBox(
            width: double.maxFinite,
            height: 400,
            child: matches.isEmpty
                ? const Center(child: Text('条件を満たす類似馬はいませんでした。'))
                : ListView.builder(
              itemCount: matches.length,
              itemBuilder: (context, index) {
                final data = matches[index];
                final isFirst = data.rank == '1';

                return Card(
                  color: isFirst ? Colors.yellow.shade50 : null,
                  child: ListTile(
                    dense: true,
                    title: Row(
                      children: [
                        Text(data.horseName, style: const TextStyle(fontWeight: FontWeight.bold)),
                        const Spacer(),
                        Text('${data.similarity.toStringAsFixed(0)}%', style: TextStyle(
                            color: data.similarity >= 80 ? Colors.red : Colors.blue,
                            fontWeight: FontWeight.bold
                        )),
                      ],
                    ),
                    subtitle: Text(
                      '${data.raceName} (${data.raceDate.split('年').first})\n'
                          '${data.popularity}番人気 → ${data.rank}着',
                      style: const TextStyle(fontSize: 12),
                    ),
                    trailing: isFirst ? const Icon(Icons.emoji_events, color: Colors.amber) : null,
                  ),
                );
              },
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('閉じる')),
          ],
        );
      },
    );
  }

  // 印の色ヘルパー
  Color _getMarkColor(String mark) {
    switch (mark) {
      case '◎': return Colors.red;
      case '○': return Colors.blue;
      case '▲': return Colors.green;
      case '△': return Colors.orange;
      case '☆': return Colors.yellow[700]!;
      default: return Colors.grey;
    }
  }

  // --- 既存のセル構築メソッド ---
  Widget _buildRotationCell(HistoricalMatchModel item) {
    Color color = Colors.black;
    if (item.rotationScore >= 90) color = Colors.red;
    else if (item.rotationScore >= 80) color = Colors.orange[800]!;
    String raceName = item.prevRaceName;
    if (raceName.length > 8) raceName = '${raceName.substring(0, 7)}...';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(item.rotDiagnosis, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12)),
        Text(raceName, style: const TextStyle(fontSize: 10, color: Colors.grey)),
      ],
    );
  }

  Widget _buildTotalScoreCell(double score, double maxScore, [double? prevScore]) {
    Color color;
    String rank;
    if (score >= maxScore && score > 0) { rank = 'S'; color = Colors.red; }
    else if (score >= 90) { rank = 'A'; color = Colors.deepOrange; }
    else if (score >= 80) { rank = 'B'; color = Colors.orange; }
    else if (score >= 70) { rank = 'C'; color = Colors.amber.shade700; }
    else if (score >= 60) { rank = 'D'; color = Colors.blue; }
    else if (score >= 50) { rank = 'E'; color = Colors.indigo; }
    else { rank = 'F'; color = Colors.grey; }

    // 差分計算
    String? diffStr;
    Color diffColor = Colors.grey;
    if (prevScore != null) {
      final diff = score - prevScore;
      if (diff != 0) {
        diffStr = diff > 0 ? '(+${diff.toStringAsFixed(0)})' : '(${diff.toStringAsFixed(0)})';
        diffColor = diff > 0 ? Colors.red : Colors.blue;
      }
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('${score.toStringAsFixed(0)}%', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 16)),
            if (diffStr != null)
              Text(diffStr, style: TextStyle(fontSize: 10, color: diffColor, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(width: 8),
        Container(width: 24, height: 20, alignment: Alignment.center, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4)), child: Text(rank, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold))),
      ],
    );
  }

  Widget _buildWeightDetailCell(HistoricalMatchModel item, [HistoricalMatchModel? prevItem]) {
    final diff = item.weightDiff;
    Color color = Colors.black;
    if (item.weightScore >= 90) color = Colors.red;
    else if (item.weightScore >= 80) color = Colors.orange[800]!;

    // スコア差分
    String? scoreDiffStr;
    if (prevItem != null) {
      final sd = item.weightScore - prevItem.weightScore;
      if (sd != 0) {
        scoreDiffStr = sd > 0 ? '+${sd.toStringAsFixed(0)}' : '${sd.toStringAsFixed(0)}';
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Row(
          children: [
            SizedBox(width: 30, child: Text('${item.weightScore.toStringAsFixed(0)}%', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 14))),
            if (scoreDiffStr != null)
              Padding(
                padding: const EdgeInsets.only(left: 2),
                child: Text('($scoreDiffStr)', style: TextStyle(fontSize: 10, color: (double.tryParse(scoreDiffStr) ?? 0) > 0 ? Colors.red : Colors.blue)),
              ),
          ],
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(item.weightStr.split(' ')[0], style: TextStyle(color: item.isWeightCurrent ? Colors.black87 : Colors.grey, fontSize: 12)),
            if (!item.isWeightCurrent) const Text('(前)', style: TextStyle(fontSize: 10, color: Colors.grey)),
            Text(' 差:${diff.toStringAsFixed(0)}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
          ],
        ),
      ],
    );
  }

  Widget _buildFrameDetailCell(HistoricalMatchModel item) {
    if (item.gateNumber == 0) return const Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [SizedBox(width: 40, child: Text('--', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14))), Text('未発表', style: TextStyle(fontSize: 11, color: Colors.grey))]);
    Color color = Colors.black;
    if (item.frameScore >= 90) color = Colors.red;
    else if (item.frameScore >= 70) color = Colors.orange[800]!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(width: 40, child: Text('${item.frameScore.toStringAsFixed(0)}%', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 14))),
        Row(mainAxisSize: MainAxisSize.min, children: [Text('${item.positionZone}目', style: const TextStyle(fontSize: 12)), const SizedBox(width: 4), Text('(${item.gateNumber}番)', style: const TextStyle(fontSize: 11, color: Colors.grey))]),
      ],
    );
  }

  // 人気妙味セルのロジック
  Widget _buildPopularityCell(HistoricalMatchModel item) {
    Color color = Colors.black;
    if (item.popularityScore >= 90) color = Colors.red;
    else if (item.popularityScore <= 40) color = Colors.blue;

    return Row(
      children: [
        Text(item.popDiagnosis, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13)),
        const SizedBox(width: 4),
        const Icon(Icons.info_outline, size: 14, color: Colors.grey),
      ],
    );
  }

  // 人気詳細ダイアログ
  void _showPopularityDetailDialog(BuildContext context, HistoricalMatchModel item) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(item.horseName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: Colors.blueGrey, borderRadius: BorderRadius.circular(4)),
                child: Text(
                  '累積指数: ${item.valueIndex >= 0 ? "+" : ""}${item.valueIndex.toStringAsFixed(1)}',
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            height: 350,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue[100]!),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(children: [Icon(Icons.psychology, size: 16, color: Colors.blue), SizedBox(width: 4), Text('AI診断', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue))]),
                      const SizedBox(height: 4),
                      Text(item.valueReasoning, style: const TextStyle(fontSize: 13, height: 1.4)),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                const Text('▼ 過去レース分析 (人気 vs 着順)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey)),
                const Divider(),
                Expanded(
                  child: item.recentHistory.isEmpty
                      ? const Center(child: Text('過去データがありません'))
                      : ListView.builder(
                    itemCount: item.recentHistory.length,
                    itemBuilder: (context, index) {
                      final rec = item.recentHistory[index];
                      final pop = int.tryParse(rec.popularity) ?? 0;
                      final rank = int.tryParse(rec.rank) ?? 0;
                      if (pop == 0 || rank == 0) return const SizedBox.shrink();

                      final diff = pop - rank;
                      IconData icon;
                      Color color;

                      if (diff >= 5) { icon = Icons.arrow_upward; color = Colors.red; }
                      else if (diff >= 1) { icon = Icons.north_east; color = Colors.orange; }
                      else if (diff == 0) { icon = Icons.arrow_forward; color = Colors.grey; }
                      else if (diff >= -3) { icon = Icons.south_east; color = Colors.blue; }
                      else { icon = Icons.arrow_downward; color = Colors.blue[900]!; }

                      return ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [Text(rec.date.split('/').sublist(1).join('/'), style: const TextStyle(fontSize: 10))],
                        ),
                        title: Text(rec.raceName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        subtitle: Text('${rec.popularity}人 → ${rec.rank}着', style: const TextStyle(fontSize: 12)),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(diff > 0 ? '+${diff}Gap' : '${diff}Gap', style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12)),
                            const SizedBox(width: 8),
                            Icon(icon, color: color),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('閉じる')),
          ],
        );
      },
    );
  }
}