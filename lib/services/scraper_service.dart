// lib/services/scraper_service.dart

import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html;
import 'package:html/dom.dart' as dom;
import 'package:hetaumakeiba_v2/models/race_result_model.dart';
import 'package:hetaumakeiba_v2/models/horse_performance_model.dart';
import 'package:hetaumakeiba_v2/models/featured_race_model.dart';
import 'package:hetaumakeiba_v2/utils/url_generator.dart';
import 'package:charset_converter/charset_converter.dart';
import 'package:hetaumakeiba_v2/db/database_helper.dart';
import 'package:hetaumakeiba_v2/models/shutuba_horse_detail_model.dart'; // 追加

class ScraperService {

  static const Map<String, String> _headers = {
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/108.0.0.0 Safari/537.36',
  };

  /// URLからレースIDを抽出するヘルパー関数
  static String? getRaceIdFromUrl(String url) {
    final uri = Uri.parse(url);
    final pathSegments = uri.pathSegments;
    if (pathSegments.isNotEmpty && pathSegments.first == 'race') {
      return pathSegments.last;
    }
    return uri.queryParameters['race_id']; // ★クエリパラメータからも取得できるよう修正
  }

  /// netkeiba.comのレース結果ページをスクレイピングし、RaceResultオブジェクトを返す
  static Future<RaceResult> scrapeRaceDetails(String url) async {
    try {
      final raceId = getRaceIdFromUrl(url);
      if (raceId == null) {
        throw Exception('無効なURLです: レースIDが取得できませんでした。');
      }

      final response = await http.get(Uri.parse(url), headers: _headers);
      if (response.statusCode != 200) {
        throw Exception('HTTPリクエストに失敗しました: Status code ${response.statusCode}');
      }

      final decodedBody = await CharsetConverter.decode('EUC-JP', response.bodyBytes);
      final document = html.parse(decodedBody);

      final raceTitle = _safeGetText(document.querySelector('div.RaceName')); // ★セレクタ修正
      final raceInfo = _safeGetText(document.querySelector('div.RaceData01')).replaceAll(RegExp(r'\s+'), ' '); // ★セレクタ修正
      final raceDate = _safeGetText(document.querySelector('title')).split('|')[1].trim().split(' ')[0]; // ★セレクタ修正
      final raceGrade = _safeGetText(document.querySelector('div.RaceData02')).replaceAll(RegExp(r'\s+'), ' '); // ★セレクタ修正
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

  /// netkeiba.comの競走馬データベースページをスクレイピングし、競走成績のリストを返します。
  static Future<List<HorseRaceRecord>> scrapeHorsePerformance(String horseId) async {
    try {
      final url = generateNetkeibaHorseUrl(horseId: horseId);
      final response = await http.get(Uri.parse(url), headers: _headers);

      if (response.statusCode != 200) {
        throw Exception('HTTPリクエストに失敗しました: Status code ${response.statusCode} for horse ID $horseId');
      }

      final decodedBody = await CharsetConverter.decode('EUC-JP', response.bodyBytes);
      final document = html.parse(decodedBody);

      final List<HorseRaceRecord> records = [];
      final table = document.querySelector('table.db_h_race_results.nk_tb_common');

      if (table == null) {
        print('警告: 競走馬ID $horseId の競走成績テーブルが見つかりませんでした。');
        return [];
      }

      final rows = table.querySelectorAll('tbody tr');

      for (final row in rows) {
        final cells = row.querySelectorAll('td');
        if (cells.length < 28) { // ★列数変更に対応
          continue;
        }

        records.add(HorseRaceRecord(
          horseId: horseId,
          date: _safeGetText(cells[0]),
          venue: _safeGetText(cells[1]),
          weather: _safeGetText(cells[2]),
          raceNumber: _safeGetText(cells[3]),
          raceName: _safeGetText(cells[4]),
          numberOfHorses: _safeGetText(cells[6]),
          frameNumber: _safeGetText(cells[7]),
          horseNumber: _safeGetText(cells[8]),
          odds: _safeGetText(cells[9]),
          popularity: _safeGetText(cells[10]),
          rank: _safeGetText(cells[11]),
          jockey: _safeGetText(cells[12].querySelector('a')),
          carriedWeight: _safeGetText(cells[13]),
          distance: _safeGetText(cells[14]),
          trackCondition: _safeGetText(cells[15]),
          time: _safeGetText(cells[17]),
          margin: _safeGetText(cells[18]),
          cornerPassage: _safeGetText(cells[20]),
          pace: _safeGetText(cells[21]),
          agari: _safeGetText(cells[22]),
          horseWeight: _safeGetText(cells[23]),
          winnerOrSecondHorse: _safeGetText(cells[26].querySelector('a')),
          prizeMoney: _safeGetText(cells[27]),
        ));
      }
      return records;
    } catch (e) {
      print('競走馬ID $horseId の競走成績スクレイピング中にエラーが発生しました: $e');
      rethrow;
    }
  }

  /// netkeiba.comのトップページから「今週の注目レース」を複数取得するよう修正
  static Future<List<FeaturedRace>> scrapeFeaturedRaces(DatabaseHelper dbHelper) async { // dbHelper を引数に追加
    final List<FeaturedRace> featuredRaces = [];
    try {
      const url = 'https://race.netkeiba.com/top/';
      final response = await http.get(Uri.parse(url), headers: _headers);

      if (response.statusCode != 200) {
        throw Exception('HTTPリクエストに失敗しました: Status code ${response.statusCode} for featured races.');
      }

      final decodedBody = await CharsetConverter.decode('EUC-JP', response.bodyBytes);

      final RegExp regExp = RegExp(
        r"showRaceV3GradeList\s*\([^,]+,\s*'(\d+)'",
        dotAll: true,
      );
      final matches = regExp.allMatches(decodedBody);

      final raceIds = matches.map((m) => m.group(1)!).toSet().toList();

      if (raceIds.isEmpty) {
        print("DEBUG: scrapeFeaturedRaces - レースIDが見つかりませんでした。");
      } else {
        print("DEBUG: scrapeFeaturedRaces - 抽出したレースID: $raceIds");
      }

      for (final raceId in raceIds) {
        final existingRace = await dbHelper.getFeaturedRace(raceId);
        if (existingRace != null && existingRace.lastScraped.isAfter(DateTime.now().subtract(const Duration(hours: 1)))) { // 1時間キャッシュ
          featuredRaces.add(existingRace);
          continue;
        }

        final shutubaRaceDetails = await _scrapeShutubaPageDetails(raceId); // ★修正されたメソッドを呼び出す
        if (shutubaRaceDetails != null) {
          // 詳細情報からFeaturedRaceオブジェクトを生成
          await dbHelper.insertOrUpdateFeaturedRace(shutubaRaceDetails);
          featuredRaces.add(shutubaRaceDetails);
        }
      }
      return featuredRaces;
    } catch (e) {
      print('注目レースのスクレイピング中にエラーが発生しました: $e');
      return [];
    }
  }

  // ▼▼▼ ここから下が修正・変更の中心箇所です ▼▼▼

  /// 出馬表ページをスクレイピングして、レース詳細情報と出走馬リストを含むFeaturedRaceオブジェクトを取得します。
  static Future<FeaturedRace?> _scrapeShutubaPageDetails(String raceId) async {
    try {
      final url = 'https://race.netkeiba.com/race/shutuba.html?race_id=$raceId';
      final response = await http.get(Uri.parse(url), headers: _headers);

      if (response.statusCode != 200) {
        print('HTTPリクエストに失敗しました: Status code ${response.statusCode} for shutuba page $raceId');
        return null;
      }

      final decodedBody = await CharsetConverter.decode('EUC-JP', response.bodyBytes);
      final document = html.parse(decodedBody);

      // --- レース基本情報の抽出 ---
      final raceNameBox = document.querySelector('div.RaceList_NameBox');
      final titleText = _safeGetText(document.querySelector('head > title'));

      // ★修正点①：raceDateをページのtitleから正規表現で抽出
      String raceDate = '';
      final dateMatch = RegExp(r'(\d{4}年\d{1,2}月\d{1,2}日)').firstMatch(titleText);
      if (dateMatch != null) {
        raceDate = dateMatch.group(1)!;
      }

      final raceName = _safeGetText(raceNameBox?.querySelector('.RaceName'));
      final raceDetails1 = _safeGetText(raceNameBox?.querySelector('.RaceData01'));
      final raceDetails2 = _safeGetText(raceNameBox?.querySelector('.RaceData02')).replaceAll(RegExp(r'\s+'), ' ');

      // ★修正点②：_scrapeShutubaHorsesを呼び出して馬リストをここで取得
      final shutubaHorses = await _scrapeShutubaHorses(document);

      return FeaturedRace(
        raceId: raceId,
        raceName: raceName,
        raceGrade: _safeGetText(raceNameBox?.querySelector('[class*="Icon_GradeType"]')),
        raceDate: raceDate,
        venue: _safeGetText(document.querySelector('.RaceKaisaiWrap .Active a')),
        raceNumber: _safeGetText(document.querySelector('.RaceNumWrap .Active a')).replaceAll('R', ''),
        shutubaTableUrl: url,
        lastScraped: DateTime.now(),
        distance: raceDetails1.split('/')[1].split('(')[0].trim(),
        conditions: '',
        weight: '',
        raceDetails1: raceDetails1,
        raceDetails2: raceDetails2,
        shutubaHorses: shutubaHorses,
      );
    } catch (e) {
      print('出馬表ページ $raceId のスクレイピング中にエラーが発生しました: $e');
      return null;
    }
  }

  /// ★修正点③：出馬表から各出走馬の詳細情報をスクレイピングするメソッド（HTMLサンプルの構造に対応）
  static Future<List<ShutubaHorseDetail>> _scrapeShutubaHorses(dom.Document document) async {
    final List<ShutubaHorseDetail> horses = [];
    // セレクタをHTMLサンプルの構造に合わせる (大文字小文字を区別)
    final horseRows = document.querySelectorAll('table.Shutuba_Table tr.HorseList');

    for (final row in horseRows) {
      final horseInfoAnchor = row.querySelector('td.HorseInfo span.HorseName a');
      if (horseInfoAnchor == null) continue;

      final horseUrl = horseInfoAnchor.attributes['href'] ?? '';
      final horseId = horseUrl.split('/').lastWhere((part) => part.isNotEmpty, orElse: () => '');
      if (horseId.isEmpty) continue;

      final oddsText = _safeGetText(row.querySelector('td.Popular span[id^="odds-"]'));
      final popularityText = _safeGetText(row.querySelector('td.Popular_Ninki span[id^="ninki-"]'));

      horses.add(ShutubaHorseDetail(
        horseId: horseId,
        horseNumber: int.tryParse(_safeGetText(row.querySelector('td.Umaban'))) ?? 0,
        gateNumber: int.tryParse(_safeGetText(row.querySelector('td.Waku > span'))) ?? 0,
        horseName: _safeGetText(horseInfoAnchor),
        sexAndAge: _safeGetText(row.querySelector('td.Barei')),
        jockey: _safeGetText(row.querySelector('td.Jockey a')),
        carriedWeight: double.tryParse(_safeGetText(row.querySelectorAll('td.Txt_C')[1])) ?? 0.0,
        odds: double.tryParse(oddsText),
        popularity: int.tryParse(popularityText.replaceAll('*', '')),
        isScratched: false,
      ));
    }
    return horses;
  }

  // ▲▲▲ ここまでが修正・変更の中心箇所です ▲▲▲


  /// 出馬表URLからraceIdを抽出するヘルパー関数
  static String? _extractRaceIdFromShutubaUrl(String url) {
    final uri = Uri.parse(url);
    return uri.queryParameters['race_id'];
  }

  /// 出馬表ページから出走馬のホースIDのリストを抽出するヘルパー関数です。
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

      // セレクタをHTMLサンプルの構造に合わせる
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
      print('出馬表ページからのホースID抽出中にエラーが発生しました: $e');
      return [];
    }
  }

  static Future<void> syncNewHorseData(List<FeaturedRace> races, DatabaseHelper dbHelper) async {
    print('[Horse Data Sync Start] 新規登録馬のデータ取得を開始します...');
    try {
      for (final race in races) {
        final List<String> horseIdsToSync = [];
        if (race.shutubaHorses != null && race.shutubaHorses!.isNotEmpty) {
          horseIdsToSync.addAll(race.shutubaHorses!.map((h) => h.horseId));
        } else {
          horseIdsToSync.addAll(await ScraperService.extractHorseIdsFromShutubaPage(race.shutubaTableUrl));
        }

        for (final horseId in horseIdsToSync.toSet()) {
          final existingRecord = await dbHelper.getLatestHorsePerformanceRecord(horseId);
          if (existingRecord == null) {
            print('新規競走馬データ取得中... Horse ID: $horseId');
            final newRecords = await ScraperService.scrapeHorsePerformance(horseId);
            for (final record in newRecords) {
              await dbHelper.insertOrUpdateHorsePerformance(record);
            }
            await Future.delayed(const Duration(milliseconds: 500));
          }
        }
      }
    } catch (e) {
      print('[Horse Data Sync Error] 新規競走馬のデータ取得中にエラーが発生しました: $e');
    }
    print('[Horse Data Sync End] 新規登録馬のデータ取得が完了しました。');
  }

  static String _safeGetText(dom.Element? element) {
    return element?.text.trim() ?? '';
  }

  static List<HorseResult> _parseHorseResults(dom.Document document) {
    final List<HorseResult> results = [];
    final rows = document.querySelectorAll('table.race_table_01 tr');

    for (var i = 1; i < rows.length; i++) {
      final cells = rows[i].querySelectorAll('td');
      if (cells.length < 21) continue;

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

  static Future<List<FeaturedRace>> scrapeMonthlyGradedRaces() async {
    try {
      return await _scrapeGradedRacesFromSchedulePage();
    } catch (e) {
      print('ホームページのデータ取得中にエラーが発生しました: $e');
      return [];
    }
  }

  static Future<List<FeaturedRace>> _scrapeGradedRacesFromSchedulePage() async {
    const url = 'https://race.netkeiba.com/top/schedule.html';
    final List<FeaturedRace> gradedRaces = [];

    final response = await http.get(Uri.parse(url), headers: _headers);
    if (response.statusCode != 200) {
      print('重賞日程ページの取得に失敗しました: Status code ${response.statusCode}');
      return [];
    }

    final decodedBody = await CharsetConverter.decode('EUC-JP', response.bodyBytes);
    final document = html.parse(decodedBody);

    final rows = document.querySelectorAll('table.race_table_01 tr');
    final currentMonth = DateTime.now().month;

    for (final row in rows) {
      final cells = row.querySelectorAll('td');
      if (cells.length < 7) continue;

      try {
        final dateStr = _safeGetText(cells[0]);
        final monthAndDay = dateStr.split('(')[0].split('/');
        final month = int.parse(monthAndDay[0]);

        if (month == currentMonth) {
          final raceName = _safeGetText(cells[1].querySelector('a'));
          final link = cells[1].querySelector('a')?.attributes['href'] ?? '';

          final raceId = 'monthly_${dateStr.replaceAll(RegExp(r'[/\(\)]'), '')}_${raceName.replaceAll(' ', '')}';

          gradedRaces.add(FeaturedRace(
            raceId: raceId,
            raceName: raceName,
            raceGrade: _safeGetText(cells[2]),
            venue: _safeGetText(cells[3]),
            distance: _safeGetText(cells[4]),
            conditions: _safeGetText(cells[5]),
            weight: _safeGetText(cells[6]),
            raceDate: dateStr,
            shutubaTableUrl: link,
            raceNumber: '',
            lastScraped: DateTime.now(),
            raceDetails1: '',
            raceDetails2: '',
            shutubaHorses: null,
          ));
        }
      } catch (e) {
        print('重賞日程の行解析エラー: $e');
        continue;
      }
    }
    return gradedRaces;
  }

  static DateTime _parseDateStringAsDateTime(String dateText) {
    try {
      final now = DateTime.now();
      final parts = RegExp(r'(\d+)年(\d+)月(\d+)日').firstMatch(dateText);
      if (parts != null) {
        return DateTime(
          int.parse(parts.group(1)!),
          int.parse(parts.group(2)!),
          int.parse(parts.group(3)!),
        );
      }
      final monthDayParts = RegExp(r'(\d+)月(\d+)日').firstMatch(dateText);
      if (monthDayParts != null) {
        return DateTime(
          now.year,
          int.parse(monthDayParts.group(1)!),
          int.parse(monthDayParts.group(2)!),
        );
      }
      return now;
    } catch (e) {
      print('Date parsing error: $dateText, Error: $e');
      return DateTime.now();
    }
  }
}