// lib/services/statistics_service.dart

import 'package:hetaumakeiba_v2/db/database_helper.dart';
import 'package:hetaumakeiba_v2/models/race_result_model.dart';
import 'package:hetaumakeiba_v2/models/race_statistics_model.dart';
import 'package:hetaumakeiba_v2/services/scraper_service.dart';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html;
import 'package:charset_converter/charset_converter.dart';
import 'dart:convert';

class StatisticsService {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  // 外部から直接呼び出されるメインの処理
  Future<RaceStatistics?> processAndSaveRaceStatistics(String raceId, String raceName) async {
    // 1. 過去10年分のレースIDリストを取得
    final pastRaceIds = await ScraperService.fetchPastRaceIdsByName(raceName);
    if (pastRaceIds.isEmpty) {
      throw Exception('過去のレースIDを取得できませんでした。');
    }

    // 2. 各レースIDの結果を取得してDBに保存
    final List<RaceResult> pastResults = [];
    for (final pastId in pastRaceIds) {
      // 既存のレース結果取得ロジックを再利用
      final result = await ScraperService.scrapeRaceDetails('https://db.netkeiba.com/race/$pastId');
      await _dbHelper.insertOrUpdateRaceResult(result);
      pastResults.add(result);
    }

    // 3. 統計データを計算
    final statistics = _calculateStatistics(pastResults);

    // 4. 計算結果をDBに保存するためのモデルを作成
    final statsToSave = RaceStatistics(
      raceId: raceId,
      raceName: raceName,
      statisticsJson: json.encode(statistics),
      lastUpdatedAt: DateTime.now(),
    );

    // 5. DBに保存
    await _dbHelper.insertOrUpdateRaceStatistics(statsToSave);
    return statsToSave;
  }

  // netkeibaから過去10年分のレースIDをスクレイピングする
  Future<List<String>> _fetchPast10RaceIds(String raceId) async {
    final url = 'https://race.netkeiba.com/race/past10.html?race_id=$raceId';
    final List<String> pastIds = [];

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode != 200) return [];

      final decodedBody = await CharsetConverter.decode('EUC-JP', response.bodyBytes);
      final document = html.parse(decodedBody);

      final links = document.querySelectorAll('td.Race_Name a');
      for (final link in links) {
        final href = link.attributes['href'];
        if (href != null) {
          final id = ScraperService.getRaceIdFromUrl(href);
          if (id != null) {
            pastIds.add(id);
          }
        }
      }
      return pastIds;
    } catch (e) {
      print('Error fetching past 10 race IDs: $e');
      return [];
    }
  }

  // 取得したレース結果リストから統計を計算する
  Map<String, dynamic> _calculateStatistics(List<RaceResult> results) {
    // ここで詳細な統計計算ロジックを実装
    // 例：人気別勝率、配当金の平均・最高・最低など

    // (今回はプレースホルダーとして簡単な集計のみ実装)
    final Map<String, Map<String, int>> popularityStats = {};
    for (int i = 1; i <= 18; i++) {
      popularityStats[i.toString()] = {'total': 0, 'win': 0, 'place': 0, 'show': 0};
    }

    for (final result in results) {
      for (final horse in result.horseResults) {
        final popularity = int.tryParse(horse.popularity);
        final rank = int.tryParse(horse.rank);
        if (popularity != null && rank != null) {
          final key = popularity.toString();
          if (popularityStats.containsKey(key)) {
            popularityStats[key]!['total'] = (popularityStats[key]!['total'] ?? 0) + 1;
            if (rank == 1) popularityStats[key]!['win'] = (popularityStats[key]!['win'] ?? 0) + 1;
            if (rank <= 2) popularityStats[key]!['place'] = (popularityStats[key]!['place'] ?? 0) + 1;
            if (rank <= 3) popularityStats[key]!['show'] = (popularityStats[key]!['show'] ?? 0) + 1;
          }
        }
      }
    }

    return {
      'analyzedYears': results.map((r) => r.raceDate.substring(0, 4)).toSet().toList(),
      'popularityStats': popularityStats,
    };
  }
}