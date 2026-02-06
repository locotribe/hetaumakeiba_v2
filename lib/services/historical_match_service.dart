// lib/services/historical_match_service.dart

import 'package:flutter/foundation.dart';
import 'package:hetaumakeiba_v2/db/database_helper.dart';
import 'package:hetaumakeiba_v2/models/race_result_model.dart';
import 'package:hetaumakeiba_v2/models/horse_performance_model.dart';
import 'package:hetaumakeiba_v2/services/horse_performance_scraper_service.dart';

class HistoricalMatchService {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  /// 指定されたレース名（例: "東京新聞杯"）に関連する過去データをDBから収集・補完します。
  ///
  /// フロー:
  /// 1. DBの race_results テーブルから同名の過去レースを検索
  /// 2. 各レースの1着〜3着馬のIDを抽出
  /// 3. 各馬について、DBの horse_performance テーブルに戦績があるか確認
  /// 4. 戦績がない場合のみ、HorsePerformanceScraperService を使ってWebから取得し、DBに保存
  Future<void> collectHistoricalData(String currentRaceName, {Function(String)? onProgress}) async {
    try {
      if (onProgress != null) onProgress('過去レースをDBから検索中...');

      // 1. DBから同名の過去レースを検索
      final List<RaceResult> pastRaces = await _dbHelper.searchRaceResultsByName(currentRaceName);

      if (pastRaces.isEmpty) {
        if (onProgress != null) onProgress('該当する過去レースがDBに見つかりませんでした。');
        return;
      }

      // 2. 分析対象とする馬IDのリストを作成 (各レースの1~3着)
      final Set<String> targetHorseIds = {};

      for (final race in pastRaces) {
        // 1着〜3着の馬をフィルタリング
        final topHorses = race.horseResults.where((h) {
          final rankStr = h.rank;
          if (rankStr == null) return false;
          final rank = int.tryParse(rankStr);
          return rank != null && rank >= 1 && rank <= 3;
        });

        for (final horse in topHorses) {
          if (horse.horseId.isNotEmpty) {
            targetHorseIds.add(horse.horseId);
          }
        }
      }

      int processedCount = 0;
      final total = targetHorseIds.length;
      if (onProgress != null) onProgress('対象馬: $total頭');

      // 3 & 4. 各馬のデータ確認と取得・保存
      for (final horseId in targetHorseIds) {
        processedCount++;

        // DBに戦績があるか確認
        final List<HorseRaceRecord> existingRecords = await _dbHelper.getHorseRaceRecords(horseId);

        if (existingRecords.isEmpty) {
          if (onProgress != null) {
            onProgress('データ取得中 ($processedCount/$total): ID $horseId');
          }

          // データがない場合のみスクレイピング実行 (既存サービスの再利用)
          await _fetchAndSaveHorseData(horseId);
        } else {
          // 既にデータがある場合はスキップ
          if (onProgress != null) {
            onProgress('データ確認済 ($processedCount/$total): ID $horseId');
          }
        }
      }

      if (onProgress != null) onProgress('データ収集完了');

    } catch (e) {
      debugPrint('Error in collectHistoricalData: $e');
      rethrow;
    }
  }

  /// スクレイピングを実行し、結果をDBに保存する内部メソッド
  Future<void> _fetchAndSaveHorseData(String horseId) async {
    // スクレイピング (既存サービス利用)
    final List<HorseRaceRecord> records =
    await HorsePerformanceScraperService.scrapeHorsePerformance(horseId);

    // DB保存
    if (records.isNotEmpty) {
      await _dbHelper.insertHorseRaceRecords(records);
    }

    // サーバー負荷軽減のための待機 (1秒)
    await Future.delayed(const Duration(milliseconds: 1000));
  }
}