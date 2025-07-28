// lib/services/scraper_service.dart
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html;
import 'package:html/dom.dart' as dom;
import 'package:hetaumakeiba_v2/models/race_result_model.dart';
import 'package:hetaumakeiba_v2/models/horse_performance_model.dart';
import 'package:hetaumakeiba_v2/models/featured_race_model.dart';
import 'package:hetaumakeiba_v2/utils/url_generator.dart';
import 'package:charset_converter/charset_converter.dart';
// Step 1で作成した新しいデータモデルをインポート
import 'package:hetaumakeiba_v2/models/home_page_data_model.dart';


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
  // 既存の関数はここまで (変更なし)

  // ★★★★★ ここからが新規追加箇所 ★★★★★

  /// ホームページに必要な「重賞レース」と「開催場別レース」の両方のデータを取得する新しいメイン関数
  static Future<HomePageData> scrapeHomePageData() async {
    try {
      // 2つのページから並行してデータを取得
      final results = await Future.wait([
        _scrapeGradedRacesFromSchedulePage(),
        _scrapeRacesByVenueFromRaceListPage(),
      ]);

      // 取得したデータをHomePageDataモデルにまとめて返す
      return HomePageData(
        gradedRaces: results[0] as List<FeaturedRace>,
        racesByVenue: results[1] as List<VenueRaces>,
      );
    } catch (e) {
      print('ホームページのデータ取得中にエラーが発生しました: $e');
      // エラー時は空のデータを返す
      return HomePageData(gradedRaces: [], racesByVenue: []);
    }
  }

  /// 「重賞日程」ページから今週のG1, G2, G3レースを取得するヘルパー関数
  static Future<List<FeaturedRace>> _scrapeGradedRacesFromSchedulePage() async {
    const url = 'https://race.netkeiba.com/top/schedule.html';
    final List<FeaturedRace> gradedRaces = [];
    final now = DateTime.now();

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
      if (cells.length < 7) continue;

      final dateStr = _safeGetText(cells[0]); // 例: 08/03(日)
      final raceName = _safeGetText(cells[1].querySelector('a'));
      final raceGrade = _safeGetText(cells[2]);
      final venue = _safeGetText(cells[3]);
      final link = cells[1].querySelector('a')?.attributes['href'];

      if (link == null) continue;

      // 今週のレースかどうかを判定 (月と日から)
      try {
        final parts = dateStr.split('(')[0].split('/');
        final month = int.parse(parts[0]);
        final day = int.parse(parts[1]);
        final raceDate = DateTime(now.year, month, day);

        // 今週の月曜日から来週の日曜日までの範囲で判定
        final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
        final endOfWeek = startOfWeek.add(const Duration(days: 13));

        if (raceDate.isAfter(startOfWeek.subtract(const Duration(days: 1))) && raceDate.isBefore(endOfWeek)) {
          // netkeibaの特集ページリンクからrace_idを取得するのは困難なため、
          // ここではダミーのIDとURLを設定します。詳細はhome_page側でハンドリング。
          // TODO: race_idを特定するより高度なロジックが必要な場合は別途実装
          final fullDate = '${now.year}年${month}月${day}日';

          gradedRaces.add(FeaturedRace(
            raceId: 'graded_${venue}_${raceName}', //暫定ID
            raceName: raceName,
            raceGrade: raceGrade,
            raceDate: fullDate,
            venue: venue,
            raceNumber: '', // このページからは取得不可
            shutubaTableUrl: 'https://race.netkeiba.com$link',
            lastScraped: DateTime.now(),
          ));
        }
      } catch (e) {
        print('重賞日程の日付解析エラー: $dateStr, $e');
      }
    }
    return gradedRaces;
  }

  /// 「今週のレース一覧」ページから開催場ごとの全レースを取得するヘルパー関数
  static Future<List<VenueRaces>> _scrapeRacesByVenueFromRaceListPage() async {
    const url = 'https://race.netkeiba.com/top/race_list.html';
    final List<VenueRaces> venues = [];

    final response = await http.get(Uri.parse(url));
    if (response.statusCode != 200) {
      print('今週のレース一覧ページの取得に失敗しました: Status code ${response.statusCode}');
      return [];
    }

    final decodedBody = await CharsetConverter.decode('EUC-JP', response.bodyBytes);
    final document = html.parse(decodedBody);

    final venueTabs = document.querySelectorAll('div.RaceList_Kaijou');
    final dateTabs = document.querySelectorAll('#date_list_sub li');

    for (int i = 0; i < venueTabs.length; i++) {
      final venueTab = venueTabs[i];
      final venueName = _safeGetText(venueTab.querySelector('.RaceList_Kaijou_Name'));
      final date = (i < dateTabs.length) ? _safeGetText(dateTabs[i]) : '';

      final List<SimpleRaceInfo> races = [];
      final raceRows = venueTab.querySelectorAll('tr.RaceList_DataItem');

      for (final row in raceRows) {
        final raceNumEl = row.querySelector('td:nth-child(1) div.Race_Num');
        final raceNameEl = row.querySelector('td:nth-child(2) div.RaceList_ItemTitle span.RaceName');
        final conditionEl = row.querySelector('td:nth-child(2) div.RaceList_ItemTitle span.RaceData');
        final linkEl = row.querySelector('a');

        if (raceNumEl == null || raceNameEl == null || linkEl == null) continue;

        final raceId = _extractRaceIdFromShutubaUrl(linkEl.attributes['href'] ?? '') ?? '';
        if (raceId.isEmpty) continue;

        final raceDataText = _safeGetText(conditionEl);
        final parts = raceDataText.split(' ');

        races.add(SimpleRaceInfo(
          raceId: raceId,
          raceNumber: _safeGetText(raceNumEl),
          raceName: _safeGetText(raceNameEl),
          distance: parts.isNotEmpty ? parts[0] : '',
          conditions: parts.length > 1 ? parts.sublist(1).join(' ') : '',
        ));
      }

      if (races.isNotEmpty) {
        venues.add(VenueRaces(
          venueName: venueName,
          date: date,
          races: races,
        ));
      }
    }
    return venues;
  }
}
