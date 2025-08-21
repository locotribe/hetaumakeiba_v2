// lib/services/statistics_service.dart

import 'package:hetaumakeiba_v2/db/database_helper.dart';
import 'package:hetaumakeiba_v2/models/race_result_model.dart';
import 'package:hetaumakeiba_v2/models/race_statistics_model.dart';
import 'package:hetaumakeiba_v2/services/scraper_service.dart';
import 'dart:convert';
import 'package:hetaumakeiba_v2/logic/parse.dart';
import 'package:hetaumakeiba_v2/logic/combination_calculator.dart';

class StatisticsService {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  /// 分析のために、指定されたレースの過去結果リストを取得する
  Future<List<RaceResult>> fetchPastRacesForAnalysis(String raceName, String raceId) async {
    // scraper_serviceから全ての候補IDを取得
    final pastRaceIdCandidates = await ScraperService.scrapePastRaceIdsFromSearch(
      raceName: raceName,
    );

    if (pastRaceIdCandidates.isEmpty) {
      print('警告: $raceName の過去レースID候補が見つかりませんでした。');
      return [];
    }
    print('【情報】${pastRaceIdCandidates.length}件の過去レースID候補が見つかりました。');

    final List<RaceResult> pastResults = [];
    for (final pastId in pastRaceIdCandidates) {
      // まずDBから試みる
      RaceResult? result = await _dbHelper.getRaceResult(pastId);
      if (result == null) {
        // DBになければスクレイピング
        print('DBに無いためWebから取得: $pastId');
        result = await ScraperService.scrapeRaceDetails('https://db.netkeiba.com/race/$pastId');
        await _dbHelper.insertOrUpdateRaceResult(result);
        await Future.delayed(const Duration(milliseconds: 200)); // サーバー負荷軽減
      }

      // 照合ロジックを撤廃し、取得した結果をそのまま追加する
      pastResults.add(result);
    }

    print('【最終結果】${pastResults.length}件の過去レース結果を取得しました。');

    return pastResults;
  }

  // 外部から直接呼び出されるメインの処理
  Future<RaceStatistics?> processAndSaveRaceStatistics(String raceId, String raceName) async {
    // 1. 過去レース結果のリストを取得 (新メソッドを利用)
    final pastResults = await fetchPastRacesForAnalysis(raceName, raceId);

    if (pastResults.isEmpty) {
      throw Exception('過去のレース結果を取得できませんでした。');
    }

    // 2. 統計データを計算
    final statistics = _calculateStatistics(pastResults);

    // 3. 計算結果をDBに保存するためのモデルを作成
    final statsToSave = RaceStatistics(
      raceId: raceId,
      raceName: raceName,
      statisticsJson: json.encode(statistics),
      lastUpdatedAt: DateTime.now(),
    );

    // 4. DBに保存
    await _dbHelper.insertOrUpdateRaceStatistics(statsToSave);
    return statsToSave;
  }


  // 取得したレース結果リストから統計を計算する
  Map<String, dynamic> _calculateStatistics(List<RaceResult> results) {
    // 各分析項目用のMapを初期化
    final Map<String, Map<String, dynamic>> popularityStats = {};
    final Map<String, Map<String, dynamic>> frameStats = {};
    final Map<String, Map<String, dynamic>> jockeyStats = {};
    final Map<String, Map<String, dynamic>> trainerStats = {};
    final Map<String, Map<String, dynamic>> legStyleStats = {};
    final Map<String, List<int>> payoutStats = {
      for (var v in bettingDict.values) v: []
    };
    final Map<String, Map<String, dynamic>> horseWeightChangeStats = {};
    final List<int> winningHorseWeights = [];

    // 集計用のループ
    for (final result in results) {
      // 配当データの集計
      for (final refund in result.refunds) {
        final ticketTypeName = bettingDict[refund.ticketTypeId];
        if (ticketTypeName != null && payoutStats.containsKey(ticketTypeName)) {
          for (final payout in refund.payouts) {
            final amount = int.tryParse(payout.amount.replaceAll(',', '')) ?? 0;
            if (amount > 0) {
              payoutStats[ticketTypeName]?.add(amount);
            }
          }
        }
      }

      for (final horse in result.horseResults) {
        final rank = int.tryParse(horse.rank);
        if (rank == null) continue; // 着順が数値でない馬は集計から除外

        final isWin = rank == 1;
        final isPlace = rank <= 2;
        final isShow = rank <= 3;

        // 人気別成績
        final popularity = horse.popularity;
        popularityStats.putIfAbsent(popularity, () => {'total': 0, 'win': 0, 'place': 0, 'show': 0});
        popularityStats[popularity]!['total'] = (popularityStats[popularity]!['total'] ?? 0) + 1;
        if (isWin) popularityStats[popularity]!['win'] = (popularityStats[popularity]!['win'] ?? 0) + 1;
        if (isPlace) popularityStats[popularity]!['place'] = (popularityStats[popularity]!['place'] ?? 0) + 1;
        if (isShow) popularityStats[popularity]!['show'] = (popularityStats[popularity]!['show'] ?? 0) + 1;

        // 枠番別成績
        final frame = horse.frameNumber;
        frameStats.putIfAbsent(frame, () => {'total': 0, 'win': 0, 'place': 0, 'show': 0});
        frameStats[frame]!['total'] = (frameStats[frame]!['total'] ?? 0) + 1;
        if (isWin) frameStats[frame]!['win'] = (frameStats[frame]!['win'] ?? 0) + 1;
        if (isPlace) frameStats[frame]!['place'] = (frameStats[frame]!['place'] ?? 0) + 1;
        if (isShow) frameStats[frame]!['show'] = (frameStats[frame]!['show'] ?? 0) + 1;

        // 騎手別成績
        final jockey = horse.jockeyName;
        jockeyStats.putIfAbsent(jockey, () => {'total': 0, 'win': 0, 'place': 0, 'show': 0});
        jockeyStats[jockey]!['total'] = (jockeyStats[jockey]!['total'] ?? 0) + 1;
        if (isWin) jockeyStats[jockey]!['win'] = (jockeyStats[jockey]!['win'] ?? 0) + 1;
        if (isPlace) jockeyStats[jockey]!['place'] = (jockeyStats[jockey]!['place'] ?? 0) + 1;
        if (isShow) jockeyStats[jockey]!['show'] = (jockeyStats[jockey]!['show'] ?? 0) + 1;

        // 調教師別成績
        final trainer = horse.trainerName;
        trainerStats.putIfAbsent(trainer, () => {'total': 0, 'win': 0, 'place': 0, 'show': 0});
        trainerStats[trainer]!['total'] = (trainerStats[trainer]!['total'] ?? 0) + 1;
        if (isWin) trainerStats[trainer]!['win'] = (trainerStats[trainer]!['win'] ?? 0) + 1;
        if (isPlace) trainerStats[trainer]!['place'] = (trainerStats[trainer]!['place'] ?? 0) + 1;
        if (isShow) trainerStats[trainer]!['show'] = (trainerStats[trainer]!['show'] ?? 0) + 1;

        // 脚質別成績 (最終コーナーの位置で判定)
        final horseCount = result.horseResults.length;
        final cornerRanks = horse.cornerRanking.split('-').map((e) => int.tryParse(e)).where((e) => e != null).cast<int>().toList();
        if (cornerRanks.isNotEmpty) {
          final lastCornerPosition = cornerRanks.last;
          final positionRate = lastCornerPosition / horseCount;
          String style;
          if (positionRate <= 0.15) style = '逃げ';
          else if (positionRate <= 0.40) style = '先行';
          else if (positionRate <= 0.80) style = '差し';
          else style = '追込';
          legStyleStats.putIfAbsent(style, () => {'total': 0, 'win': 0, 'place': 0, 'show': 0});
          legStyleStats[style]!['total'] = (legStyleStats[style]!['total'] ?? 0) + 1;
          if (isWin) legStyleStats[style]!['win'] = (legStyleStats[style]!['win'] ?? 0) + 1;
          if (isPlace) legStyleStats[style]!['place'] = (legStyleStats[style]!['place'] ?? 0) + 1;
          if (isShow) legStyleStats[style]!['show'] = (legStyleStats[style]!['show'] ?? 0) + 1;
        }

        // 馬体重別成績
        final weightMatch = RegExp(r'(\d+)\(([\+\-]\d+)\)').firstMatch(horse.horseWeight);
        if (weightMatch != null) {
          final weight = int.tryParse(weightMatch.group(1)!);
          final weightChange = int.tryParse(weightMatch.group(2)!);
          if (weight != null && weightChange != null) {
            if(isWin) winningHorseWeights.add(weight);
            String category;
            if (weightChange <= -10) category = '-10kg以下';
            else if (weightChange <= -4) category = '-4~-8kg';
            else if (weightChange <= 2) category = '-2~+2kg';
            else if (weightChange <= 8) category = '+4~+8kg';
            else category = '+10kg以上';

            horseWeightChangeStats.putIfAbsent(category, () => {'total': 0, 'win': 0, 'place': 0, 'show': 0});
            horseWeightChangeStats[category]!['total'] = (horseWeightChangeStats[category]!['total'] ?? 0) + 1;
            if (isWin) horseWeightChangeStats[category]!['win'] = (horseWeightChangeStats[category]!['win'] ?? 0) + 1;
            if (isPlace) horseWeightChangeStats[category]!['place'] = (horseWeightChangeStats[category]!['place'] ?? 0) + 1;
            if (isShow) horseWeightChangeStats[category]!['show'] = (horseWeightChangeStats[category]!['show'] ?? 0) + 1;
          }
        }
      }
    }

    final Map<String, dynamic> finalPayoutStats = {};
    payoutStats.forEach((key, value) {
      if (value.isNotEmpty) {
        finalPayoutStats[key] = {
          'average': (value.reduce((a, b) => a + b) / value.length).round(),
          'max': value.reduce((a, b) => a > b ? a : b),
          'min': value.reduce((a, b) => a < b ? a : b),
        };
      }
    });

    final double avgWinningHorseWeight = winningHorseWeights.isNotEmpty
        ? winningHorseWeights.reduce((a, b) => a + b) / winningHorseWeights.length
        : 0.0;

    return {
      'analyzedYears': results.map((r) => r.raceDate.substring(0, 4)).toSet().toList(),
      'popularityStats': popularityStats,
      'frameStats': frameStats,
      'jockeyStats': jockeyStats,
      'trainerStats': trainerStats,
      'legStyleStats': legStyleStats,
      'payoutStats': finalPayoutStats,
      'horseWeightChangeStats': horseWeightChangeStats,
      'avgWinningHorseWeight': avgWinningHorseWeight,
    };
  }
}