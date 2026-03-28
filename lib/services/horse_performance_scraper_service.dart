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
    try {
      final url = generateNetkeibaHorseUrl(horseId: horseId);
      final response = await http.get(Uri.parse(url), headers: _headers);

      if (response.statusCode == 200) {
        final document = html.parse(await CharsetConverter.decode('euc-jp', response.bodyBytes));
        final rows = document.querySelectorAll('.db_h_race_results tbody tr');
        final List<HorseRaceRecord> records = [];

        for (var row in rows) {
          final cells = row.querySelectorAll('td');
          if (cells.length < 28) continue; // 行のデータが足りない場合はスキップ

          final raceNameLink = cells[4].querySelector('a');
          final String? raceHref = raceNameLink?.attributes['href'];
          // ドメインの強制連結を解除し、そのまま関数へ渡す
          final raceId = raceHref != null ? RaceResultScraperService.getRaceIdFromUrl(raceHref) ?? '' : '';

          final jockeyLink = cells[12].querySelector('a');
          final String? jockeyHref = jockeyLink?.attributes['href'];
          final jockeyId = jockeyHref != null
              ? jockeyHref.split('/').firstWhere(
                  (s) => RegExp(r'^\d{5}$').hasMatch(s), orElse: () => '')
              : '';

          // [修正] netkeibaのテーブル列数（標準28列 / プレミアム仕様33列以上）に応じて取得インデックスを動的に切り替える (v.1.0)
          final bool isPremiumLayout = cells.length >= 33;

          final String cornerPassage = cells[isPremiumLayout ? 25 : 21].text.trim();
          final String pace = cells[isPremiumLayout ? 26 : 22].text.trim();
          final String agari = cells[isPremiumLayout ? 27 : 23].text.trim();
          final String horseWeight = cells[isPremiumLayout ? 28 : 24].text.trim();
          final String winnerOrSecondHorse = cells[isPremiumLayout ? 31 : 26].text.trim();
          final String prizeMoney = cells[isPremiumLayout ? 32 : 27].text.trim();

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
            cornerPassage: cornerPassage,
            pace: pace,
            agari: agari,
            horseWeight: horseWeight,
            winnerOrSecondHorse: winnerOrSecondHorse,
            prizeMoney: prizeMoney,
          ));
        }
        return records;
      } else {
        return [];
      }
    } catch (e) {
      return [];
    }
  }
}