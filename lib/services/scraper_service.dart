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
    return null;
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

      // ★ここから下のメソッド呼び出しがエラーになっていた部分です
      final raceTitle = _safeGetText(document.querySelector('div.race_head h1'));
      final raceInfo = _safeGetText(document.querySelector('div.data_intro p.diary_snap_cut span')).replaceAll(RegExp(r'\s+'), ' ');
      final raceDate = _safeGetText(document.querySelector('p.smalltxt')).split(' ').first; // Stringのまま
      final raceGrade = _safeGetText(document.querySelector('p.smalltxt')).split(' ').last;
      final horseResults = _parseHorseResults(document); // ★再追加
      final refunds = _parseRefunds(document);           // ★再追加
      final cornerPassages = _parseCornerPassages(document); // ★再追加
      final lapTimes = _parseLapTimes(document);         // ★再追加

      return RaceResult(
        raceId: raceId,
        raceTitle: raceTitle,
        raceInfo: raceInfo,
        raceDate: raceDate, // RaceResultではStringのまま
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
        if (cells.length < 23) {
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
        // DBに存在し、かつ最終スクレイピングから一定時間経過していない場合はスキップ
        final existingRace = await dbHelper.getFeaturedRace(raceId);
        // raceDate は String のままなので isAfter で比較する際は parse する必要がある
        if (existingRace != null && existingRace.lastScraped.isAfter(DateTime.now().subtract(const Duration(minutes: 30)))) { // 30分キャッシュ
          featuredRaces.add(existingRace);
          continue;
        }

        final shutubaRaceDetails = await _scrapeShutubaPageDetails(raceId); // Map<String, String?>を返す
        if (shutubaRaceDetails != null) {
          List<ShutubaHorseDetail> shutubaHorses = [];
          try {
            // ここで出馬表URLを使って各馬の詳細をスクレイピング
            shutubaHorses = await ScraperService._scrapeShutubaHorses(shutubaRaceDetails['shutubaTableUrl']!); // ★修正：クラス名で呼び出し
          } catch (e) {
            print('Error scraping shutuba horses for race $raceId: $e');
          }

          final featuredRace = FeaturedRace(
            id: existingRace?.id, // IDを保持 (新規ならnull)
            raceId: shutubaRaceDetails['raceId']!,
            raceName: shutubaRaceDetails['raceName']!,
            raceGrade: shutubaRaceDetails['raceGrade']!,
            raceDate: shutubaRaceDetails['raceDate']!, // ★Stringのまま
            venue: shutubaRaceDetails['venue']!,
            raceNumber: shutubaRaceDetails['raceNumber']!,
            shutubaTableUrl: shutubaRaceDetails['shutubaTableUrl']!,
            lastScraped: DateTime.now(),
            distance: shutubaRaceDetails['distance'] ?? '',
            conditions: shutubaRaceDetails['conditions'] ?? '',
            weight: shutubaRaceDetails['weight'] ?? '',
            raceDetails1: shutubaRaceDetails['raceDetails1'],
            raceDetails2: shutubaRaceDetails['raceDetails2'],
            shutubaHorses: shutubaHorses,
          );
          await dbHelper.insertOrUpdateFeaturedRace(featuredRace);
          featuredRaces.add(featuredRace);
        }
      }
      return featuredRaces;
    } catch (e) {
      print('注目レースのスクレイピング中にエラーが発生しました: $e');
      return [];
    }
  }

  /// 出馬表URLからraceIdを抽出するヘルパー関数
  static String? _extractRaceIdFromShutubaUrl(String url) {
    final uri = Uri.parse(url);
    final pathSegments = uri.pathSegments; // 追加
    if (pathSegments.isNotEmpty && pathSegments[pathSegments.length -1].startsWith('?race_id=')) { // URLの形式に合わせて修正
      return uri.queryParameters['race_id'];
    }
    return null;
  }

  /// 出馬表ページをスクレイピングしてレース詳細情報を取得します。
  static Future<Map<String, String?>?> _scrapeShutubaPageDetails(String raceId) async {
    try {
      final url = 'https://race.netkeiba.com/race/shutuba.html?race_id=$raceId';
      final response = await http.get(Uri.parse(url), headers: _headers);

      if (response.statusCode != 200) {
        print('HTTPリクエストに失敗しました: Status code ${response.statusCode} for shutuba page $raceId');
        return null;
      }

      final decodedBody = await CharsetConverter.decode('EUC-JP', response.bodyBytes);
      final document = html.parse(decodedBody);

      final raceNameElement = document.querySelector('h1.RaceName');
      final raceName = _safeGetText(raceNameElement);

      final raceGradeElement = raceNameElement?.querySelector('span[class*="Icon_GradeType"]');
      String raceGrade = '';
      if (raceGradeElement != null) {
        final classList = raceGradeElement.classes;
        for (final cls in classList) {
          if (cls.startsWith('Icon_GradeType') && cls.length > 14) {
            raceGrade = 'G${cls.substring(14)}';
            break;
          }
        }
        if (raceGrade.isEmpty && classList.contains('Icon_GradeType13')) {
          raceGrade = 'J・G';
        }
      }

      final raceNumElement = document.querySelector('span.RaceNum');
      final raceNumber = _safeGetText(raceNumElement).replaceAll('R', '');

      final raceKaisaiWrap = document.querySelector('div.RaceKaisaiWrap ul.Col');
      final activeVenueElement = raceKaisaiWrap?.querySelector('li.Active a');
      final venue = _safeGetText(activeVenueElement);

      final dateElement = document.querySelector('div.RaceList_Date_Top dd.Active a');
      String raceDate = '';
      if (dateElement != null) {
        final dateText = _safeGetText(dateElement);
        final monthDay = dateText.split('(')[0];
        final currentYear = DateTime.now().year;
        raceDate = '$currentYear年$monthDay';
      }

      final raceData1 = document.querySelector('div.RaceData01');
      final details1 = raceData1?.text.replaceAll(RegExp(r'\s+'), ' ').trim();

      final raceData2 = document.querySelector('div.RaceData02');
      final details2 = raceData2?.text.replaceAll(RegExp(r'\s+'), ' ').trim();

      String distance = '';
      String conditions = '';
      String weight = '';

      if (details1 != null) {
        final parts = details1.split(' ');
        for (final part in parts) {
          if (part.contains('m') && (part.contains('芝') || part.contains('ダ') || part.contains('障'))) {
            distance = part;
          } else if (part.contains('歳上') || part.contains('歳') || part.contains('クラス') || part.contains('G') || part.contains('OP') || part.contains('未勝利') || part.contains('新馬')) {
            conditions = part;
          } else if (part.contains('kg') || part.contains('斤')) {
            weight = part;
          }
        }
      }

      return {
        'raceId': raceId,
        'raceName': raceName,
        'raceGrade': raceGrade,
        'raceDate': raceDate,
        'venue': venue,
        'raceNumber': raceNumber,
        'shutubaTableUrl': url,
        'distance': distance,
        'conditions': conditions,
        'weight': weight,
        'raceDetails1': details1,
        'raceDetails2': details2,
      };
    } catch (e) {
      print('出馬表ページ $raceId のスクレイピング中にエラーが発生しました: $e');
      return null;
    }
  }

  /// ★追加：出馬表から各出走馬の詳細情報をスクレイピングするプライベートメソッド
  static Future<List<ShutubaHorseDetail>> _scrapeShutubaHorses(String shutubaUrl) async {
    try {
      final response = await http.get(Uri.parse(shutubaUrl));

      if (response.statusCode == 200) {
        final String decodedBody = await CharsetConverter.decode(
          "EUC-JP",
          response.bodyBytes,
        );
        final document = html.parse(decodedBody);
        final List<ShutubaHorseDetail> horses = [];

        // Netkeibaの出馬表テーブルの行セレクタは `HorseList` クラスを持つ `tr`
        final horseRows = document.querySelectorAll('table.shutuba_table tr.HorseList');

        for (final row in horseRows) {
          // 馬ID、馬名、性齢は 'horse_info' td 内の a タグから取得
          final horseInfoTd = row.querySelector('td.horse_info');
          final horseLink = horseInfoTd?.querySelector('a[href*="/horse/"]');
          final horseId = horseLink?.attributes['href']?.split('/').last;

          if (horseId == null) {
            print('Warning: Horse ID not found for a row in $shutubaUrl');
            continue;
          }

          final horseName = horseLink?.text.trim() ?? '';
          final sexAndAge = horseInfoTd?.querySelector('p.txt_info')?.text.trim() ?? '';

          // 馬番と枠番は 'umaban' td から取得
          // NetkeibaのHTML構造は頻繁に変わるため、より堅牢なセレクタを試す
          final umabanTd = row.querySelector('td.umaban');
          final horseNumber = int.tryParse(umabanTd?.querySelector('span.umaban')?.text.trim() ?? '0') ?? 0; // span.umabanを追加
          final gateNumber = int.tryParse(umabanTd?.querySelector('p.wakuban')?.text.trim() ?? '0') ?? 0; // p.wakubanを追加


          // 騎手と斤量
          final jockeyTd = row.querySelector('td.jockey');
          final jockey = jockeyTd?.querySelector('a')?.text.trim() ?? '';
          final carriedWeight = double.tryParse(jockeyTd?.querySelector('span.jockey_weight')?.text.trim() ?? '0.0') ?? 0.0;

          // オッズと人気
          final oddsTd = row.querySelector('td.odds');
          final odds = double.tryParse(oddsTd?.querySelector('span.Odds')?.text.trim() ?? '');
          final popularity = int.tryParse(oddsTd?.querySelector('span.Popularity')?.text.trim().replaceAll('人気', '') ?? '');

          // 出走取消は行全体に 'Cancel_Txt' または 'Disqualification' クラスが付与される
          final isScratched = row.classes.contains('Cancel_Txt') || row.classes.contains('Disqualification');


          horses.add(ShutubaHorseDetail(
            horseId: horseId,
            horseNumber: horseNumber,
            gateNumber: gateNumber,
            horseName: horseName,
            sexAndAge: sexAndAge,
            jockey: jockey,
            carriedWeight: carriedWeight,
            odds: odds,
            popularity: popularity,
            isScratched: isScratched,
          ));
        }
        return horses;
      } else {
        print('Failed to load shutuba page: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      print('Error scraping shutuba horses: $e');
      return [];
    }
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

      final horseLinks = document.querySelectorAll('table.shutuba_table a[href*="/horse/"]'); // ここもshutuba_tableに修正

      for (final link in horseLinks) {
        final href = link.attributes['href'];
        if (href != null) {
          final uri = Uri.parse(href);
          if (uri.pathSegments.length >= 2 && uri.pathSegments[0] == 'horse') {
            horseIds.add(uri.pathSegments[1]);
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
          } else {
            print('DEBUG: 競走馬ID ${horseId} の最新成績は既に存在します。スキップします。');
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

  // ★以下のプライベートメソッドを再追加
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

  /// ホームページに表示する「今月の重賞レース」データを取得する
  static Future<List<FeaturedRace>> scrapeMonthlyGradedRaces() async { // ★再追加
    try {
      return await _scrapeGradedRacesFromSchedulePage();
    } catch (e) {
      print('ホームページのデータ取得中にエラーが発生しました: $e');
      return [];
    }
  }

  /// 「重賞日程」ページから今月の重賞レースを取得するヘルパー関数
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
    for (final row in rows) {
      final cells = row.querySelectorAll('td');
      if (cells.length < 7) continue;

      try {
        final dateStr = _safeGetText(cells[0]);
        final monthAndDay = dateStr.split('(')[0].split('/');
        final month = int.parse(monthAndDay[0]);

        if (month == DateTime.now().month) {
          final raceName = _safeGetText(cells[1].querySelector('a'));
          final link = cells[1].querySelector('a')?.attributes['href'] ?? '';

          final raceId = 'monthly_graded_${dateStr.replaceAll(RegExp(r'[/\(\)]'), '')}_${raceName.replaceAll(' ', '')}';

          gradedRaces.add(FeaturedRace(
            id: null, // id は AUTOINCREMENT なので null を渡す
            raceId: raceId,
            raceName: raceName,
            raceGrade: _safeGetText(cells[2]),
            venue: _safeGetText(cells[3]),
            distance: _safeGetText(cells[4]),
            conditions: _safeGetText(cells[5]),
            weight: _safeGetText(cells[6]),
            raceDate: dateStr, // Stringのまま
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

  // _parseDateStringAsDateTime は FeaturedRace モデルの raceDate が String 型なので String のまま返す。
  // ただし、DateFomat などで使うために DateTime に変換したい場合は、呼び出し側で変換する。
  // このメソッドは元々プライベートとして存在。
  static DateTime _parseDateStringAsDateTime(String dateText) { // 新しいヘルパー関数
    try {
      final parts = RegExp(r'(\d+)年(\d+)月(\d+)日').firstMatch(dateText);
      if (parts != null && parts.groupCount >= 3) {
        final year = int.parse(parts.group(1)!);
        final month = int.parse(parts.group(2)!);
        final day = int.parse(parts.group(3)!);
        return DateTime(year, month, day);
      }
      final currentYear = DateTime.now().year;
      final monthDayParts = RegExp(r'(\d+)月(\d+)日').firstMatch(dateText);
      if (monthDayParts != null && monthDayParts.groupCount >= 2) {
        final month = int.parse(monthDayParts.group(1)!);
        final day = int.parse(monthDayParts.group(2)!);
        return DateTime(currentYear, month, day);
      }
      return DateTime.now();
    } catch (e) {
      print('Date parsing error: $dateText, Error: $e');
      return DateTime.now();
    }
  }
}