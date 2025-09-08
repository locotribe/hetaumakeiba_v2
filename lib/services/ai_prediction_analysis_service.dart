// lib/services/ai_prediction_analysis_service.dart

import 'package:hetaumakeiba_v2/db/database_helper.dart';
import 'package:hetaumakeiba_v2/models/ai_prediction_model.dart';
import 'package:hetaumakeiba_v2/models/race_result_model.dart';
import 'package:hetaumakeiba_v2/logic/ai_prediction_analyzer.dart';
import 'package:hetaumakeiba_v2/models/horse_performance_model.dart';

// AI予測全体の分析結果サマリーを保持するクラス
class AiOverallAnalysis {
  final int totalHonmeiCount; // 本命（◎）にした回数
  final int honmeiWinCount; // 本命が1着だった回数
  final int honmeiPlaceCount; // 本命が2着以内だった回数
  final int honmeiShowCount; // 本命が3着以内だった回数
  final double totalWinInvestment; // 単勝の総投資額
  final double totalWinPayout; // 単勝の総払戻額
  final double totalShowInvestment; // 複勝の総投資額
  final double totalShowPayout; // 複勝の総払戻額

  AiOverallAnalysis({
    this.totalHonmeiCount = 0,
    this.honmeiWinCount = 0,
    this.honmeiPlaceCount = 0,
    this.honmeiShowCount = 0,
    this.totalWinInvestment = 0,
    this.totalWinPayout = 0,
    this.totalShowInvestment = 0,
    this.totalShowPayout = 0,
  });

  // 勝率
  double get winRate => totalHonmeiCount > 0 ? (honmeiWinCount / totalHonmeiCount) * 100 : 0;
  // 連対率
  double get placeRate => totalHonmeiCount > 0 ? (honmeiPlaceCount / totalHonmeiCount) * 100 : 0;
  // 複勝率
  double get showRate => totalHonmeiCount > 0 ? (honmeiShowCount / totalHonmeiCount) * 100 : 0;
  // 単勝回収率
  double get winRecoveryRate => totalWinInvestment > 0 ? (totalWinPayout / totalWinInvestment) * 100 : 0;
  // 複勝回収率
  double get showRecoveryRate => totalShowInvestment > 0 ? (totalShowPayout / totalShowInvestment) * 100 : 0;
}

// 特定のファクター（競馬場、距離など）ごとの分析結果を保持するクラス
class AiFactorAnalysis {
  final String factorName; // 分析対象の要素名 (例: "東京", "芝1600m")
  final AiOverallAnalysis analysis; // その要素における総合分析結果

  AiFactorAnalysis({
    required this.factorName,
    required this.analysis,
  });
}

class AiPredictionAnalysisService {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  // データベースから全予測・全結果を読み込み、分析を行うメインメソッド
  Future<Map<String, dynamic>> analyzeAllPredictions(String userId) async {
    // 1. 必要なデータをDBから全て取得
    final allRaceResults = await _getAllRaceResults();
    final allPredictions = await _getAllAiPredictions();
    final allHorseIds = allPredictions.map((p) => p.horseId).toSet();
    final Map<String, List<HorseRaceRecord>> allPastRecords = {};
    for (final horseId in allHorseIds) {
      allPastRecords[horseId] = await _dbHelper.getHorsePerformanceRecords(horseId);
    }

    // 2. レースIDをキーにしてデータを整理
    final Map<String, List<AiPrediction>> predictionsByRace = {};
    for (final p in allPredictions) {
      predictionsByRace.putIfAbsent(p.raceId, () => []).add(p);
    }

    // 3. 全レースをループして本命馬の成績を集計
    int totalHonmeiCount = 0;
    int honmeiWinCount = 0;
    int honmeiPlaceCount = 0;
    int honmeiShowCount = 0;
    double totalWinInvestment = 0;
    double totalWinPayout = 0;
    double totalShowInvestment = 0;
    double totalShowPayout = 0;

    for (final raceId in predictionsByRace.keys) {
      final raceResult = allRaceResults[raceId];
      final predictions = predictionsByRace[raceId]!;
      if (raceResult == null || raceResult.isIncomplete) continue;

      // 総合スコアが最も高い馬を本命（◎）とする
      predictions.sort((a, b) => b.overallScore.compareTo(a.overallScore));
      final honmeiPrediction = predictions.first;

      // 本命馬のレース結果を探す
      HorseResult? honmeiResult;
      try {
        honmeiResult = raceResult.horseResults.firstWhere((hr) => hr.horseId == honmeiPrediction.horseId);
      } catch (e) {
        continue; // レース結果にいない場合 (除外など) はスキップ
      }

      final rank = int.tryParse(honmeiResult.rank);
      if (rank == null) continue;

      totalHonmeiCount++;
      if (rank == 1) honmeiWinCount++;
      if (rank <= 2) honmeiPlaceCount++;
      if (rank <= 3) honmeiShowCount++;

      // 単勝回収率の計算
      final odds = double.tryParse(honmeiResult.odds);
      if (odds != null) {
        totalWinInvestment += 100; // 1レース100円と仮定
        if (rank == 1) {
          totalWinPayout += 100 * odds;
        }
      }

      // 複勝回収率の計算
      final fukushoRefund = raceResult.refunds.firstWhere((r) => r.ticketTypeId == '2', orElse: () => Refund(ticketTypeId: '', payouts: []));
      if (fukushoRefund.payouts.isNotEmpty) {
        totalShowInvestment += 100;
        if (rank <= 3) {
          final honmeiHorseNumber = int.tryParse(honmeiResult.horseNumber);
          for (final payout in fukushoRefund.payouts) {
            if (payout.combinationNumbers.contains(honmeiHorseNumber)) {
              totalShowPayout += double.tryParse(payout.amount.replaceAll(',', '')) ?? 0;
              break;
            }
          }
        }
      }
    }

    final overallAnalysis = AiOverallAnalysis(
      totalHonmeiCount: totalHonmeiCount,
      honmeiWinCount: honmeiWinCount,
      honmeiPlaceCount: honmeiPlaceCount,
      honmeiShowCount: honmeiShowCount,
      totalWinInvestment: totalWinInvestment,
      totalWinPayout: totalWinPayout,
      totalShowInvestment: totalShowInvestment,
      totalShowPayout: totalShowPayout,
    );

    // TODO: ここに競馬場別、距離別などのファクター分析ロジックを追加する

    // ファクター分析用の集計マップ
    final Map<String, AiOverallAnalysis> venueAnalysis = {};
    final Map<String, AiOverallAnalysis> distanceAnalysis = {};
    final Map<String, AiOverallAnalysis> trackConditionAnalysis = {};
    final Map<String, AiOverallAnalysis> popularityAnalysis = {};
    final Map<String, AiOverallAnalysis> legStyleAnalysis = {};

    // レース情報を解析してファクターごとに集計
    for (final raceId in predictionsByRace.keys) {
      final raceResult = allRaceResults[raceId];
      final predictions = predictionsByRace[raceId]!;
      if (raceResult == null || raceResult.isIncomplete) continue;

      predictions.sort((a, b) => b.overallScore.compareTo(a.overallScore));
      final honmeiPrediction = predictions.first;

      HorseResult? honmeiResult;
      try {
        honmeiResult = raceResult.horseResults.firstWhere((hr) => hr.horseId == honmeiPrediction.horseId);
      } catch (e) {
        continue;
      }

      final rank = int.tryParse(honmeiResult.rank);
      if (rank == null) continue;

      // ファクターを抽出
      final venue = _extractVenue(raceId);
      final distance = _extractDistance(raceResult.raceInfo);
      final trackCondition = _extractTrackCondition(raceResult.raceInfo);
      final popularity = _extractPopularity(honmeiResult);
      final legStyle = AiPredictionAnalyzer.getRunningStyle(allPastRecords[honmeiPrediction.horseId] ?? []);

      // ファクターごとに成績を更新
      _updateFactorAnalysis(venueAnalysis, venue, honmeiResult, raceResult);
      _updateFactorAnalysis(distanceAnalysis, distance, honmeiResult, raceResult);
      _updateFactorAnalysis(trackConditionAnalysis, trackCondition, honmeiResult, raceResult);
      _updateFactorAnalysis(popularityAnalysis, popularity, honmeiResult, raceResult);
      _updateFactorAnalysis(legStyleAnalysis, legStyle, honmeiResult, raceResult);
    }


    return {
      'overall': overallAnalysis,
      // 'byVenue': (競馬場ごとの分析結果リスト),
      'byVenue': venueAnalysis.entries.map((e) => AiFactorAnalysis(factorName: e.key, analysis: e.value)).toList(),
      'byDistance': distanceAnalysis.entries.map((e) => AiFactorAnalysis(factorName: e.key, analysis: e.value)).toList(),
      'byTrackCondition': trackConditionAnalysis.entries.map((e) => AiFactorAnalysis(factorName: e.key, analysis: e.value)).toList(),
      'byPopularity': popularityAnalysis.entries.map((e) => AiFactorAnalysis(factorName: e.key, analysis: e.value)).toList(),
      'byLegStyle': legStyleAnalysis.entries.map((e) => AiFactorAnalysis(factorName: e.key, analysis: e.value)).toList(), // ← この行を追加
    };
  }

  // DBから全レース結果を一度に取得するヘルパー
  Future<Map<String, RaceResult>> _getAllRaceResults() async {
    final db = await _dbHelper.database;
    final maps = await db.query('race_results');
    final Map<String, RaceResult> results = {};
    for (final map in maps) {
      final result = raceResultFromJson(map['race_result_json'] as String);
      results[result.raceId] = result;
    }
    return results;
  }

  // DBから全AI予測を一度に取得するヘルパー
  Future<List<AiPrediction>> _getAllAiPredictions() async {
    final db = await _dbHelper.database;
    final maps = await db.query('ai_predictions');
    return maps.map((map) => AiPrediction.fromMap(map)).toList();
  }

  // ファクター分析の集計を更新するヘルパーメソッド
  void _updateFactorAnalysis(Map<String, AiOverallAnalysis> analysisMap, String factor, HorseResult honmeiResult, RaceResult raceResult) {
    if (factor.isEmpty) return;

    final rank = int.tryParse(honmeiResult.rank);
    if (rank == null) return;

    final analysis = analysisMap.putIfAbsent(factor, () => AiOverallAnalysis());

    final newTotalCount = analysis.totalHonmeiCount + 1;
    final newWinCount = analysis.honmeiWinCount + (rank == 1 ? 1 : 0);
    final newPlaceCount = analysis.honmeiPlaceCount + (rank <= 2 ? 1 : 0);
    final newShowCount = analysis.honmeiShowCount + (rank <= 3 ? 1 : 0);

    double winInvestmentDelta = 0;
    double winPayoutDelta = 0;
    double showInvestmentDelta = 0;
    double showPayoutDelta = 0;

    final odds = double.tryParse(honmeiResult.odds);
    if (odds != null) {
      winInvestmentDelta = 100;
      if (rank == 1) {
        winPayoutDelta = 100 * odds;
      }
    }

    final fukushoRefund = raceResult.refunds.firstWhere((r) => r.ticketTypeId == '2', orElse: () => Refund(ticketTypeId: '', payouts: []));
    if (fukushoRefund.payouts.isNotEmpty) {
      showInvestmentDelta = 100;
      if (rank <= 3) {
        final honmeiHorseNumber = int.tryParse(honmeiResult.horseNumber);
        for (final payout in fukushoRefund.payouts) {
          if (payout.combinationNumbers.contains(honmeiHorseNumber)) {
            showPayoutDelta = (double.tryParse(payout.amount.replaceAll(',', '')) ?? 0);
            break;
          }
        }
      }
    }

    analysisMap[factor] = AiOverallAnalysis(
      totalHonmeiCount: newTotalCount,
      honmeiWinCount: newWinCount,
      honmeiPlaceCount: newPlaceCount,
      honmeiShowCount: newShowCount,
      totalWinInvestment: analysis.totalWinInvestment + winInvestmentDelta,
      totalWinPayout: analysis.totalWinPayout + winPayoutDelta,
      totalShowInvestment: analysis.totalShowInvestment + showInvestmentDelta,
      totalShowPayout: analysis.totalShowPayout + showPayoutDelta,
    );
  }


  // レースIDから競馬場名を抽出するヘルパー
  String _extractVenue(String raceId) {
    if (raceId.length >= 6) {
      const racecourseDict = {
        "01": "札幌", "02": "函館", "03": "福島", "04": "新潟", "05": "東京",
        "06": "中山", "07": "中京", "08": "京都", "09": "阪神", "10": "小倉",
      };
      final code = raceId.substring(4, 6);
      return racecourseDict[code] ?? '';
    }
    return '';
  }

  // レース情報から距離を抽出するヘルパー
  String _extractDistance(String raceInfo) {
    final distanceMatch = RegExp(r'(芝|ダ|障)(?:右|左|直線)?(\d+)m').firstMatch(raceInfo);
    if (distanceMatch != null) {
      return '${distanceMatch.group(1)}${distanceMatch.group(2)}';
    }
    return '';
  }

  // レース情報から馬場状態を抽出するヘルパー
  String _extractTrackCondition(String raceInfo) {
    if (raceInfo.contains('稍重')) return '稍重';
    if (raceInfo.contains('重')) return '重';
    if (raceInfo.contains('不良')) return '不良';
    if (raceInfo.contains('良')) return '良';
    return '';
  }

  // レース結果から人気を抽出するヘルパー
  String _extractPopularity(HorseResult horseResult) {
    final popularity = int.tryParse(horseResult.popularity);
    if (popularity != null) {
      return '$popularity番人気';
    }
    return '';
  }
}