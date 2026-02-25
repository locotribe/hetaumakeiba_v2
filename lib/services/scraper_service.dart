// lib/services/scraper_service.dart

import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html;
import 'package:html/dom.dart' as dom;
import 'package:hetaumakeiba_v2/models/featured_race_model.dart';
import 'package:hetaumakeiba_v2/utils/url_generator.dart';
import 'package:charset_converter/charset_converter.dart';
import 'package:hetaumakeiba_v2/db/repositories/horse_repository.dart';
import 'package:hetaumakeiba_v2/services/race_result_scraper_service.dart';
import 'package:hetaumakeiba_v2/services/horse_performance_scraper_service.dart';

class ScraperService {

  static const Map<String, String> _headers = {
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/108.0.0.0 Safari/537.36',
    'x-requested-with': 'XMLHttpRequest',
  };

  /// dom.Elementから安全にテキストを取得するヘルパー関数
  static String _safeGetText(dom.Element? element) {
    return element?.text.trim() ?? '';
  }

  /// 出馬表ページから出走馬のIDリストのみを抽出する (馬券登録時のバックグラウンド処理で使用)
  static Future<List<String>> extractHorseIdsFromShutubaPage(String shutubaTableUrl) async {
    final List<String> horseIds = [];
    try {
      final response = await http.get(Uri.parse(shutubaTableUrl), headers: _headers);

      if (response.statusCode != 200) {
        print('HTTPリクエストに失敗しました: Status code ${response.statusCode} for shutuba page $shutubaTableUrl');
        return [];
      }

      final decodedBody = await CharsetConverter.decode('EUC-JP', response.bodyBytes);
      final document = html.parse(decodedBody);

      final horseLinks = document.querySelectorAll('table.Shutuba_Table td.HorseInfo a[href*="/horse/"]');

      for (final link in horseLinks) {
        final href = link.attributes['href'];
        if (href != null) {
          final horseId = href.split('/').lastWhere((part) => part.isNotEmpty, orElse: () => '');
          if (horseId.isNotEmpty) {
            horseIds.add(horseId);
          }
        }
      }
      return horseIds.toSet().toList();
    } catch (e) {
      print('[ERROR]出馬表ページからのホースID抽出中にエラーが発生しました: $e');
      return [];
    }
  }

  /// 過去レース結果がない馬の成績データをバックグラウンドで取得し同期する
  static Future<void> syncNewHorseData(List<FeaturedRace> races) async {
    print('[Horse Data Sync Start] 競走馬データの同期を開始します...');
    final HorseRepository horseRepository = HorseRepository();
    try {
      for (final race in races) {
        final List<String> horseIdsToSync = [];
        if (race.shutubaHorses != null && race.shutubaHorses!.isNotEmpty) {
          horseIdsToSync.addAll(race.shutubaHorses!.map((h) => h.horseId));
        } else {
          horseIdsToSync.addAll(await ScraperService.extractHorseIdsFromShutubaPage(race.shutubaTableUrl));
        }

        for (final horseId in horseIdsToSync.toSet()) {
          final existingRecord = await horseRepository.getLatestHorsePerformanceRecord(horseId);
          if (existingRecord != null && existingRecord.raceId.isNotEmpty) {
            continue;
          }
          print('競走馬データ取得/更新中... Horse ID: $horseId');
          final newRecords = await HorsePerformanceScraperService.scrapeHorsePerformance(horseId);

          // リポジトリ経由で保存（一括保存）
          await horseRepository.insertHorseRaceRecords(newRecords);

          await Future.delayed(const Duration(milliseconds: 500));
        }
      }
    } catch (e) {
      print('[Horse Data Sync Error] 競走馬のデータ同期中にエラーが発生しました: $e');
    }
    print('[Horse Data Sync End] 競走馬データの同期が完了しました。');
  }

  /// レース名から過去10年分のレースIDリストをスクレイピングする (統計分析機能で使用)
  static Future<List<String>> scrapePastRaceIdsFromSearch({
    required String raceName,
  }) async {
    final searchUrl = await generateNetkeibaRaceSearchUrl(raceName: raceName);
    final List<String> pastIds = [];
    final currentYear = DateTime.now().year;

    try {
      final response = await http.get(Uri.parse(searchUrl), headers: _headers);
      if (response.statusCode != 200) {
        print('レース名検索ページの取得に失敗: $searchUrl (Status: ${response.statusCode})');
        return [];
      }

      final decodedBody = await CharsetConverter.decode('EUC-JP', response.bodyBytes);
      final document = html.parse(decodedBody);

      final table = document.querySelector('table.race_table_01');
      if (table == null) return [];

      final rows = table.querySelectorAll('tr');

      for (final row in rows) {
        final cells = row.querySelectorAll('td');
        if (cells.length < 5) continue;

        final raceNameCell = cells[4].querySelector('a');
        if (raceNameCell == null) continue;

        final dateText = _safeGetText(cells[0]);
        final yearMatch = RegExp(r'(\d{4})/\d{2}/\d{2}').firstMatch(dateText);
        if (yearMatch != null) {
          final year = int.parse(yearMatch.group(1)!);
          if (year >= currentYear - 10 && year < currentYear) {
            final href = raceNameCell.attributes['href'];
            if (href != null) {
              final id = RaceResultScraperService.getRaceIdFromUrl(href);
              if (id != null) {
                pastIds.add(id);
              }
            }
          }
        }
      }
      return pastIds;
    } catch (e) {
      print('Error fetching past race IDs by name: $e');
      return [];
    }
  }

  /// DB検索結果ページ（HTML）から過去のレース一覧情報を抽出する
  static List<Map<String, String>> scrapeRaceIdListFromDbPage(String htmlContent) {
    final document = html.parse(htmlContent);
    final List<Map<String, String>> results = [];

    final rows = document.querySelectorAll('table.race_table_01 tr');
    // ヘッダー行を除外するために1から開始
    for (var i = 1; i < rows.length; i++) {
      final cells = rows[i].querySelectorAll('td');
      if (cells.length < 7) continue;

      try {
        // 1列目: 開催日 (例: 2025/01/26)
        final date = _safeGetText(cells[0]);
        // 2列目: 開催場 (例: 1中山9)
        final venue = _safeGetText(cells[1]);
        // 5列目: レース名とID
        final raceNameElement = cells[4].querySelector('a');
        final raceName = raceNameElement != null ? _safeGetText(raceNameElement) : '';
        final href = raceNameElement?.attributes['href'];
        final raceId = href != null ? RaceResultScraperService.getRaceIdFromUrl(href) : '';
        // 7列目: 距離 (例: 芝2000)
        final distance = _safeGetText(cells[6]);

        if (raceId != null && raceId.isNotEmpty) {
          results.add({
            'raceId': raceId,
            'date': date,
            'venue': venue,
            'raceName': raceName,
            'distance': distance,
          });
        }
      } catch (e) {
        print('[ERROR] DB検索結果の行解析エラー: $e');
        continue;
      }
    }
    return results;
  }
}