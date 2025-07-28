// lib/services/scraper_service.dart
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html;
import 'package:html/dom.dart' as dom;
import 'package:hetaumakeiba_v2/models/race_result_model.dart';
import 'package:hetaumakeiba_v2/models/horse_performance_model.dart'; // ★★★★★ 追加：競走馬成績モデルをインポート ★★★★★
import 'package:hetaumakeiba_v2/utils/url_generator.dart'; // ★★★★★ 追加：URL生成ユーティリティをインポート ★★★★★
import 'package:charset_converter/charset_converter.dart';

class ScraperService {
  /// URLからレースIDを抽出するヘルパー関数
  static String? getRaceIdFromUrl(String url) {
    final uri = Uri.parse(url);
    final pathSegments = uri.pathSegments;
    if (pathSegments.isNotEmpty && pathSegments.first == 'race') {
      return pathSegments.last;
    }
    return null;
  }

  /// netkeiba.comのレース結果ページをスクレイピングし、RaceResultオブジェクトを返す
  static Future<RaceResult> scrapeRaceDetails(String url) async {
    try {
      final raceId = getRaceIdFromUrl(url);
      if (raceId == null) {
        throw Exception('無効なURLです: レースIDが取得できませんでした。');
      }

      final response = await http.get(Uri.parse(url));
      if (response.statusCode != 200) {
        throw Exception('HTTPリクエストに失敗しました: Status code ${response.statusCode}');
      }

      // EUC-JPからUTF-8へ文字コードを変換
      final decodedBody = await CharsetConverter.decode('EUC-JP', response.bodyBytes);
      final document = html.parse(decodedBody);

      // 各解析パートを個別の関数に分離
      final raceTitle = _parseRaceTitle(document);
      final raceInfo = _parseRaceInfo(document);
      final raceDate = _parseRaceDate(document);
      final raceGrade = _parseRaceGrade(document);
      final horseResults = _parseHorseResults(document);
      final refunds = _parseRefunds(document);
      final cornerPassages = _parseCornerPassages(document);
      final lapTimes = _parseLapTimes(document);

      return RaceResult(
        raceId: raceId,
        raceTitle: raceTitle,
        raceInfo: raceInfo,
        raceDate: raceDate,
        raceGrade: raceGrade,
        horseResults: horseResults,
        refunds: refunds,
        cornerPassages: cornerPassages,
        lapTimes: lapTimes,
      );
    } catch (e) {
      print('スクレイピングエラー: $e');
      rethrow;
    }
  }

  /// ★★★★★ ここから追加 ★★★★★

  /// netkeiba.comの競走馬データベースページをスクレイピングし、競走成績のリストを返します。
  static Future<List<HorseRaceRecord>> scrapeHorsePerformance(String horseId) async {
    try {
      final url = generateNetkeibaHorseUrl(horseId: horseId); // 新しく追加したURL生成関数を使用
      final response = await http.get(Uri.parse(url));

      if (response.statusCode != 200) {
        throw Exception('HTTPリクエストに失敗しました: Status code ${response.statusCode} for horse ID $horseId');
      }

      // EUC-JPからUTF-8へ文字コードを変換
      final decodedBody = await CharsetConverter.decode('EUC-JP', response.bodyBytes);
      final document = html.parse(decodedBody);

      final List<HorseRaceRecord> records = [];
      // 競走成績テーブルのセレクタは、競走馬データベースページサンプル.txt の内容から推測
      // class="db_h_race_results nk_tb_common" のテーブルを対象とする
      final table = document.querySelector('table.db_h_race_results.nk_tb_common');

      if (table == null) {
        print('警告: 競走馬ID $horseId の競走成績テーブルが見つかりませんでした。');
        return [];
      }

      // ヘッダー行をスキップしてデータ行を処理
      final rows = table.querySelectorAll('tbody tr');

      for (final row in rows) {
        final cells = row.querySelectorAll('td');
        // 期待するセルの数（最低限のデータがあるか確認）
        if (cells.length < 23) { // 取得したい競走馬データ.txt に記載の項目数より少し多めに設定
          continue;
        }

        // 各セルのテキストを安全に取得
        final date = _safeGetText(cells[0]);
        final venue = _safeGetText(cells[1]);
        final weather = _safeGetText(cells[2]);
        final raceNumber = _safeGetText(cells[3]);
        final raceName = _safeGetText(cells[4]);
        // cells[5] は映像リンクなのでスキップ
        final numberOfHorses = _safeGetText(cells[6]);
        final frameNumber = _safeGetText(cells[7]);
        final horseNumber = _safeGetText(cells[8]);
        final odds = _safeGetText(cells[9]);
        final popularity = _safeGetText(cells[10]);
        final rank = _safeGetText(cells[11]);
        final jockey = _safeGetText(cells[12].querySelector('a')); // 騎手はaタグの中
        final carriedWeight = _safeGetText(cells[13]);
        final distance = _safeGetText(cells[14]);
        final trackCondition = _safeGetText(cells[15]);
        // cells[16] は馬場指数なのでスキップ
        final time = _safeGetText(cells[17]);
        final margin = _safeGetText(cells[18]);
        // cells[19] はタイム指数なのでスキップ
        final cornerPassage = _safeGetText(cells[20]);
        final pace = _safeGetText(cells[21]);
        final agari = _safeGetText(cells[22]);
        final horseWeight = _safeGetText(cells[23]);
        // cells[24] は厩舎コメントなのでスキップ
        // cells[25] は備考なのでスキップ
        final winnerOrSecondHorse = _safeGetText(cells[26].querySelector('a')); // 勝ち馬(2着馬)はaタグの中
        final prizeMoney = _safeGetText(cells[27]);

        records.add(HorseRaceRecord(
          horseId: horseId,
          date: date,
          venue: venue,
          weather: weather,
          raceNumber: raceNumber,
          raceName: raceName,
          numberOfHorses: numberOfHorses,
          frameNumber: frameNumber,
          horseNumber: horseNumber,
          odds: odds,
          popularity: popularity,
          rank: rank,
          jockey: jockey,
          carriedWeight: carriedWeight,
          distance: distance,
          trackCondition: trackCondition,
          time: time,
          margin: margin,
          cornerPassage: cornerPassage,
          pace: pace,
          agari: agari,
          horseWeight: horseWeight,
          winnerOrSecondHorse: winnerOrSecondHorse,
          prizeMoney: prizeMoney,
        ));
      }
      return records;
    } catch (e) {
      print('競走馬ID $horseId の競走成績スクレイピング中にエラーが発生しました: $e');
      rethrow;
    }
  }

  /// ★★★★★ ここまで追加 ★★★★★

  // Elementから安全にテキストを取得するヘルパー
  static String _safeGetText(dom.Element? element) {
    return element?.text.trim() ?? '';
  }

  // レース名を取得
  static String _parseRaceTitle(dom.Document document) {
    return _safeGetText(document.querySelector('div.race_head h1'));
  }

  // コース情報、天候、馬場状態を取得
  static String _parseRaceInfo(dom.Document document) {
    final infoElement = document.querySelector('div.data_intro p.diary_snap_cut span');
    return _safeGetText(infoElement).replaceAll(RegExp(r'\s+'), ' ');
  }

  // 開催日を取得
  static String _parseRaceDate(dom.Document document) {
    final smallTxt = _safeGetText(document.querySelector('p.smalltxt'));
    return smallTxt.split(' ').first;
  }

  // レース条件を取得
  static String _parseRaceGrade(dom.Document document) {
    final smallTxt = _safeGetText(document.querySelector('p.smalltxt'));
    return smallTxt.split(' ').last;
  }

  // 全出走馬の結果を取得
  static List<HorseResult> _parseHorseResults(dom.Document document) {
    final List<HorseResult> results = [];
    final rows = document.querySelectorAll('table.race_table_01 tr');

    for (var i = 1; i < rows.length; i++) { // ヘッダー行をスキップ
      final cells = rows[i].querySelectorAll('td');
      if (cells.length < 21) continue; // データが不十分な行はスキップ

      final horseLink = cells[3].querySelector('a');
      final horseId = horseLink?.attributes['href']?.split('/')[2] ?? '';

      results.add(HorseResult(
        rank: _safeGetText(cells[0]),
        frameNumber: _safeGetText(cells[1]),
        horseNumber: _safeGetText(cells[2]),
        horseName: _safeGetText(horseLink),
        horseId: horseId,
        sexAndAge: _safeGetText(cells[4]),
        weightCarried: _safeGetText(cells[5]),
        jockeyName: _safeGetText(cells[6].querySelector('a')),
        time: _safeGetText(cells[7]),
        margin: _safeGetText(cells[8]),
        cornerRanking: _safeGetText(cells[10]),
        agari: _safeGetText(cells[11].querySelector('span')),
        odds: _safeGetText(cells[12]),
        popularity: _safeGetText(cells[13]),
        horseWeight: _safeGetText(cells[14]),
        trainerName: _safeGetText(cells[18].querySelector('a')),
        ownerName: _safeGetText(cells[19].querySelector('a')),
        prizeMoney: _safeGetText(cells[20]),
      ));
    }
    return results;
  }

  // 払戻情報を取得
  static List<Refund> _parseRefunds(dom.Document document) {
    final List<Refund> refundList = [];
    final payTables = document.querySelectorAll('dl.pay_block table.pay_table_01');

    for (final table in payTables) {
      final rows = table.querySelectorAll('tr');
      for (final row in rows) {
        final th = row.querySelector('th');
        final tds = row.querySelectorAll('td');
        if (th == null || tds.isEmpty) continue;

        final ticketType = _safeGetText(th);
        final payouts = <Payout>[];

        final combinations = tds[0].innerHtml.split('<br>').map((e) => e.trim()).toList();
        final amounts = tds.length > 1 ? tds[1].innerHtml.split('<br>').map((e) => e.trim()).toList() : [];
        final popularities = tds.length > 2 ? tds[2].innerHtml.split('<br>').map((e) => e.trim()).toList() : [];

        for (int i = 0; i < combinations.length; i++) {
          payouts.add(Payout(
            combination: combinations[i].replaceAll(RegExp(r'\s*→\s*'), '→'),
            amount: i < amounts.length ? amounts[i] : '',
            popularity: i < popularities.length ? popularities[i] : '',
          ));
        }
        refundList.add(Refund(ticketType: ticketType, payouts: payouts));
      }
    }
    return refundList;
  }

  // コーナー通過順位を取得
  static List<String> _parseCornerPassages(dom.Document document) {
    final List<String> passages = [];
    final table = document.querySelector('table[summary="コーナー通過順位"]');
    if (table == null) return passages;

    final rows = table.querySelectorAll('tr');
    for (final row in rows) {
      final th = _safeGetText(row.querySelector('th'));
      final td = _safeGetText(row.querySelector('td'));
      if (th.isNotEmpty && td.isNotEmpty) {
        passages.add('$th: $td');
      }
    }
    return passages;
  }

  // ラップタイムを取得
  static List<String> _parseLapTimes(dom.Document document) {
    final List<String> laps = [];
    final table = document.querySelector('table[summary="ラップタイム"]');
    if (table == null) return laps;

    final rows = table.querySelectorAll('tr');
    for (final row in rows) {
      final th = _safeGetText(row.querySelector('th'));
      final td = _safeGetText(row.querySelector('td'));
      if (th.isNotEmpty && td.isNotEmpty) {
        laps.add('$th: $td');
      }
    }
    return laps;
  }
}
