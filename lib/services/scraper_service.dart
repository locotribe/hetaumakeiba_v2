// lib/services/scraper_service.dart
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html;
import 'package:html/dom.dart' as dom;
import 'package:hetaumakeiba_v2/models/race_result_model.dart';
import 'package:hetaumakeiba_v2/models/horse_performance_model.dart';
import 'package:hetaumakeiba_v2/models/featured_race_model.dart';
import 'package:hetaumakeiba_v2/utils/url_generator.dart';
import 'package:charset_converter/charset_converter.dart';

// ▼▼▼ 不要なインポートを削除 ▼▼▼
// import 'package:hetaumakeiba_v2/models/home_page_data_model.dart';

class ScraperService {
  // 既存の関数はここから (変更なし)
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

      final decodedBody = await CharsetConverter.decode('EUC-JP', response.bodyBytes);
      final document = html.parse(decodedBody);

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

  /// netkeiba.comの競走馬データベースページをスクレイピングし、競走成績のリストを返します。
  static Future<List<HorseRaceRecord>> scrapeHorsePerformance(String horseId) async {
    try {
      final url = generateNetkeibaHorseUrl(horseId: horseId);
      final response = await http.get(Uri.parse(url));

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

  /// netkeiba.comのトップページから「今週のおすすめのレース」をスクレイピングします。(旧バージョン)
  static Future<List<FeaturedRace>> scrapeFeaturedRaces() async {
    final List<FeaturedRace> featuredRaces = [];
    try {
      const url = 'https://race.netkeiba.com/top/';
      final response = await http.get(Uri.parse(url));

      if (response.statusCode != 200) {
        throw Exception('HTTPリクエストに失敗しました: Status code ${response.statusCode} for featured races.');
      }

      final decodedBody = await CharsetConverter.decode('EUC-JP', response.bodyBytes);
      final document = html.parse(decodedBody);

      final featuredRaceLink = document.querySelector('ul.PickupRace_Other_Race li.PickupRaceMenu_Btn a');

      if (featuredRaceLink != null) {
        final relativeUrl = featuredRaceLink.attributes['href'];
        if (relativeUrl != null) {
          final fullUrl = 'https://race.netkeiba.com${relativeUrl.replaceFirst('..', '')}';
          final raceId = _extractRaceIdFromShutubaUrl(fullUrl);

          if (raceId != null) {
            final shutubaRace = await _scrapeShutubaPageDetails(raceId);
            if (shutubaRace != null) {
              featuredRaces.add(FeaturedRace(
                raceId: shutubaRace['raceId']!,
                raceName: shutubaRace['raceName']!,
                raceGrade: shutubaRace['raceGrade']!,
                raceDate: shutubaRace['raceDate']!,
                venue: shutubaRace['venue']!,
                raceNumber: shutubaRace['raceNumber']!,
                shutubaTableUrl: shutubaRace['shutubaTableUrl']!,
                lastScraped: DateTime.now(),
                // 新しいプロパティに空文字を設定
                distance: shutubaRace['distance'] ?? '',
                conditions: shutubaRace['conditions'] ?? '',
                weight: shutubaRace['weight'] ?? '',
              ));
            }
          }
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
    return uri.queryParameters['race_id'];
  }

  /// 出馬表ページをスクレイピングしてレース詳細情報を取得します。
  static Future<Map<String, String>?> _scrapeShutubaPageDetails(String raceId) async {
    try {
      final url = 'https://race.netkeiba.com/race/shutuba.html?race_id=$raceId';
      final response = await http.get(Uri.parse(url));

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
        raceDate = dateText.split('(')[0];
        final currentYear = DateTime.now().year;
        raceDate = '$currentYear年$raceDate';
      }

      return {
        'raceId': raceId,
        'raceName': raceName,
        'raceGrade': raceGrade,
        'raceDate': raceDate,
        'venue': venue,
        'raceNumber': raceNumber,
        'shutubaTableUrl': url,
      };
    } catch (e) {
      print('出馬表ページ $raceId のスクレイピング中にエラーが発生しました: $e');
      return null;
    }
  }

  /// 出馬表ページから出走馬のホースIDのリストを抽出するヘルパー関数です。
  static Future<List<String>> extractHorseIdsFromShutubaPage(String shutubaTableUrl) async {
    final List<String> horseIds = [];
    try {
      final response = await http.get(Uri.parse(shutubaTableUrl));

      if (response.statusCode != 200) {
        print('HTTPリクエストに失敗しました: Status code ${response.statusCode} for shutuba page $shutubaTableUrl');
        return [];
      }

      final decodedBody = await CharsetConverter.decode('EUC-JP', response.bodyBytes);
      final document = html.parse(decodedBody);

      final horseLinks = document.querySelectorAll('table.Shutuba_Table a[href*="/horse/"]');

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

  static String _safeGetText(dom.Element? element) {
    return element?.text.trim() ?? '';
  }

  static String _parseRaceTitle(dom.Document document) {
    return _safeGetText(document.querySelector('div.race_head h1'));
  }

  static String _parseRaceInfo(dom.Document document) {
    final infoElement = document.querySelector('div.data_intro p.diary_snap_cut span');
    return _safeGetText(infoElement).replaceAll(RegExp(r'\s+'), ' ');
  }

  static String _parseRaceDate(dom.Document document) {
    final smallTxt = _safeGetText(document.querySelector('p.smalltxt'));
    return smallTxt.split(' ').first;
  }

  static String _parseRaceGrade(dom.Document document) {
    final smallTxt = _safeGetText(document.querySelector('p.smalltxt'));
    return smallTxt.split(' ').last;
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
  // 既存の関数はここまで

  // ▼▼▼ ここからが修正・変更箇所 ▼▼▼

  /// ホームページに表示する「今月の重賞レース」データを取得する
  static Future<List<FeaturedRace>> scrapeMonthlyGradedRaces() async {
    try {
      return await _scrapeGradedRacesFromSchedulePage();
    } catch (e) {
      print('ホームページのデータ取得中にエラーが発生しました: $e');
      return []; // エラー時は空のデータを返す
    }
  }

  /// 「重賞日程」ページから今月の重賞レースを取得するヘルパー関数
  static Future<List<FeaturedRace>> _scrapeGradedRacesFromSchedulePage() async {
    const url = 'https://race.netkeiba.com/top/schedule.html';
    final List<FeaturedRace> gradedRaces = [];
    final now = DateTime.now();
    final currentYear = now.year;

    final response = await http.get(Uri.parse(url));
    if (response.statusCode != 200) {
      print('重賞日程ページの取得に失敗しました: Status code ${response.statusCode}');
      return [];
    }

    final decodedBody = await CharsetConverter.decode('EUC-JP', response.bodyBytes);
    final document = html.parse(decodedBody);

    final rows = document.querySelectorAll('table.race_table_01 tr');
    for (final row in rows) {
      final cells = row.querySelectorAll('td');
      // ヘッダー行や不正な行をスキップ
      if (cells.length < 7) continue;

      try {
        final dateStr = _safeGetText(cells[0]); // 例: 08/03(日)
        final monthAndDay = dateStr.split('(')[0].split('/');
        final month = int.parse(monthAndDay[0]);

        // 今月のレースのみを抽出
        if (month == now.month) {
          final raceName = _safeGetText(cells[1].querySelector('a'));
          final link = cells[1].querySelector('a')?.attributes['href'] ?? '';

          // このページからは詳細なrace_idが取得できないため、暫定IDを生成
          final raceId = 'monthly_graded_${_safeGetText(cells[3])}_${raceName.replaceAll(' ', '_')}';

          gradedRaces.add(FeaturedRace(
            raceId: raceId,
            raceName: raceName,
            raceGrade: _safeGetText(cells[2]),
            venue: _safeGetText(cells[3]),
            distance: _safeGetText(cells[4]),
            conditions: _safeGetText(cells[5]),
            weight: _safeGetText(cells[6]),
            // YYYY年MM/DD(曜) 形式で日付を生成
            raceDate: '$currentYear年$dateStr',
            shutubaTableUrl: link.startsWith('http') ? link : 'https://race.netkeiba.com$link',
            // このページからは取得不可のため、空文字を設定
            raceNumber: '',
            lastScraped: DateTime.now(),
          ));
        }
      } catch (e) {
        // 日付解析エラーなどは無視して次の行へ
        print('重賞日程の行解析エラー: $e');
        continue;
      }
    }
    return gradedRaces;
  }

// ▼▼▼ 不要になった関数を削除 ▼▼▼
// static Future<List<VenueRaces>> _scrapeRacesByVenueFromRaceListPage() ...
}