// lib/services/horse_performance_scraper_service.dart

import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html;
import 'package:charset_converter/charset_converter.dart';
import 'package:hetaumakeiba_v2/models/horse_performance_model.dart';
import 'package:hetaumakeiba_v2/utils/url_generator.dart';
import 'package:hetaumakeiba_v2/services/race_result_scraper_service.dart';

class HorsePerformanceScraperService {
  static const Map<String, String> _headers = {
    'User-Agent':
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/108.0.0.0 Safari/537.36',
    'x-requested-with': 'XMLHttpRequest',
  };

  /// netkeiba.comの競走馬データベースページをスクレイピングし、競走成績のリストを返します。
  /// ※プロフィールの取得は HorseProfileScraperService に分離されました。
  static Future<List<HorseRaceRecord>> scrapeHorsePerformance(String horseId) async {
    print('DEBUG: scrapeHorsePerformance called for ID: $horseId');
    try {
      final url = generateNetkeibaHorseUrl(horseId: horseId);
      final response = await http.get(Uri.parse(url), headers: _headers);

      if (response.statusCode != 200) {
        throw Exception(
            'HTTPリクエストに失敗しました: Status code ${response.statusCode} for horse ID $horseId');
      }

      final decodedBody =
      await CharsetConverter.decode('EUC-JP', response.bodyBytes);
      final document = html.parse(decodedBody);

      // ★削除: ここで _scrapeAndSaveProfile を呼んでいた処理を削除

      final List<HorseRaceRecord> records = [];
      final table =
      document.querySelector('table.db_h_race_results.nk_tb_common');

      if (table == null) {
        print('警告: 競走馬ID $horseId の競走成績テーブルが見つかりませんでした。');
        return [];
      }

      final rows = table.querySelectorAll('tbody tr');

      for (final row in rows) {
        final cells = row.querySelectorAll('td');
        if (cells.length < 29) {
          continue;
        }

        final raceNameLink = cells[4].querySelector('a');
        final raceHref = raceNameLink?.attributes['href'];
        final raceId = raceHref != null
            ? RaceResultScraperService.getRaceIdFromUrl(raceHref) ?? ''
            : '';
        final jockeyLink = cells[12].querySelector('a');
        final jockeyHref = jockeyLink?.attributes['href'];
        final jockeyId = jockeyHref != null
            ? jockeyHref.split('/').firstWhere(
                (s) => RegExp(r'^\d{5}$').hasMatch(s), orElse: () => '')
            : '';

        records.add(HorseRaceRecord(
          horseId: horseId,
          raceId: raceId,
          date: cells[0].text.trim(),
          venue: cells[1].text.trim(),
          weather: cells[2].text.trim(),
          raceNumber: cells[3].text.trim(),
          raceName: raceNameLink?.text.trim() ?? '',
          numberOfHorses: cells[6].text.trim(),
          frameNumber: cells[7].text.trim(),
          horseNumber: cells[8].text.trim(),
          odds: cells[9].text.trim(),
          popularity: cells[10].text.trim(),
          rank: cells[11].text.trim(),
          jockey: jockeyLink?.text.trim() ?? '',
          jockeyId: jockeyId,
          carriedWeight: cells[13].text.trim(),
          distance: cells[14].text.trim(),
          trackCondition: cells[16].text.trim(),
          time: cells[18].text.trim(),
          margin: cells[19].text.trim(),
          cornerPassage: cells[21].text.trim(),
          pace: cells[22].text.trim(),
          agari: cells[23].text.trim(),
          horseWeight: cells[24].text.trim(),
          winnerOrSecondHorse: cells[27].querySelector('a')?.text.trim() ?? '',
          prizeMoney: cells[28].text.trim(),
        ));
      }
      return records;
    } catch (e) {
      print('[ERROR]競走馬ID $horseId の競走成績スクレイピング中にエラーが発生しました: $e');
      rethrow;
    }
  }
}