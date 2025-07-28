// lib/services/scraper_service.dart
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html;
import 'package:html/dom.dart' as dom;
import 'package:hetaumakeiba_v2/models/race_result_model.dart';
import 'package:hetaumakeiba_v2/models/horse_performance_model.dart';
import 'package:hetaumakeiba_v2/models/featured_race_model.dart'; // ★★★★★ 追加：注目レースモデルをインポート ★★★★★
import 'package:hetaumakeiba_v2/utils/url_generator.dart';
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

  /// netkeiba.comの競走馬データベースページをスクレイピングし、競走成績のリストを返します。
  static Future<List<HorseRaceRecord>> scrapeHorsePerformance(String horseId) async {
    try {
      final url = generateNetkeibaHorseUrl(horseId: horseId);
      final response = await http.get(Uri.parse(url));

      if (response.statusCode != 200) {
        throw Exception('HTTPリクエストに失敗しました: Status code ${response.statusCode} for horse ID $horseId');
      }

      // EUC-JPからUTF-8へ文字コードを変換
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

        final date = _safeGetText(cells[0]);
        final venue = _safeGetText(cells[1]);
        final weather = _safeGetText(cells[2]);
        final raceNumber = _safeGetText(cells[3]);
        final raceName = _safeGetText(cells[4]);
        final numberOfHorses = _safeGetText(cells[6]);
        final frameNumber = _safeGetText(cells[7]);
        final horseNumber = _safeGetText(cells[8]);
        final odds = _safeGetText(cells[9]);
        final popularity = _safeGetText(cells[10]);
        final rank = _safeGetText(cells[11]);
        final jockey = _safeGetText(cells[12].querySelector('a'));
        final carriedWeight = _safeGetText(cells[13]);
        final distance = _safeGetText(cells[14]);
        final trackCondition = _safeGetText(cells[15]);
        final time = _safeGetText(cells[17]);
        final margin = _safeGetText(cells[18]);
        final cornerPassage = _safeGetText(cells[20]);
        final pace = _safeGetText(cells[21]);
        final agari = _safeGetText(cells[22]);
        final horseWeight = _safeGetText(cells[23]);
        final winnerOrSecondHorse = _safeGetText(cells[26].querySelector('a'));
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

  /// ★★★★★ ここから追加：注目レーススクレイピング関連 ★★★★★

  /// netkeiba.comのトップページから「今週のおすすめのレース」をスクレイピングします。
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

      // 「今週のおすすめのレース」セクションを特定
      // このセクションはJavaScriptで動的に読み込まれるため、直接HTMLには含まれない可能性があります。
      // その場合、JavaScriptが呼び出しているAPIを直接叩く必要があります。
      // サンプルHTMLから、`showRaceV3GradeList` が使われていることが推測されます。
      // しかし、そのAPIのURLは動的に生成されている可能性があり、直接呼び出すのは困難な場合があります。
      // まずは、HTML内の静的な部分から情報を取得できるか試みます。
      // もし以下のセレクタで情報が取得できない場合、この関数は空のリストを返すか、
      // 別のAPIエンドポイントを特定する追加調査が必要です。

      // トップページのおすすめレースは、通常 .Jra_RaceList_Inner .PickupRace_Contents 内にあります。
      // ただし、このコンテンツはJavaScriptによって動的に挿入されるため、
      // http.get() で取得した初期HTMLには含まれていない可能性が高いです。
      // 今回のサンプルHTMLでは、`TopRaceMain` というIDのdiv要素があり、
      // その中にJavaScriptでコンテンツが挿入されることを示唆しています。
      // `showRaceV3GradeList("TopRaceMain", '202504020407', '1');`
      // この関数の第二引数がrace_idなので、このrace_idを使って出馬表ページにアクセスします。
      // トップページから直接レース名などを取得するのは難しいため、
      // ここでは、サンプルHTMLから取得できるレースIDを元に、出馬表ページから情報を取得するアプローチを取ります。

      // サンプルHTMLから直接race_idを取得する（静的な部分から）
      // 実際には、複数の注目レースがある場合、それらを全て抽出する必要があります。
      // 現状のサンプルHTMLでは、一つの注目レースのrace_idがJavaScriptの引数としてハードコードされています。
      // 汎用性を考慮し、ここでは仮のraceIdを使用します。
      // 実際の運用では、NetkeibaのHTML構造を解析し、動的に表示される注目レースのリンクを抽出する必要があります。
      // ここでは、`今週の注目レースページサンプルHTML.txt` の `PickupRace_Other_Race` の最初のリンクを例とします。
      // `<a href="../race/shutuba.html?race_id=202504020407&rf=top_pickup"`
      final featuredRaceLink = document.querySelector('ul.PickupRace_Other_Race li.PickupRaceMenu_Btn a');

      if (featuredRaceLink != null) {
        final relativeUrl = featuredRaceLink.attributes['href'];
        if (relativeUrl != null) {
          final fullUrl = 'https://race.netkeiba.com$relativeUrl';
          final raceId = _extractRaceIdFromShutubaUrl(fullUrl);

          if (raceId != null) {
            // 出馬表ページをスクレイピングして詳細情報を取得
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
      // もし複数の注目レースがある場合、同様のロジックでループして追加します。
      // 例: document.querySelectorAll('div.PickupRace_Contents a[href*="shutuba.html?race_id="]')
      // を使って全ての注目レースリンクを抽出し、それぞれ処理します。

      return featuredRaces;
    } catch (e) {
      print('注目レースのスクレイピング中にエラーが発生しました: $e');
      return []; // エラー時は空のリストを返す
    }
  }

  /// 出馬表URLからraceIdを抽出するヘルパー関数
  static String? _extractRaceIdFromShutubaUrl(String url) {
    final uri = Uri.parse(url);
    return uri.queryParameters['race_id'];
  }

  /// 出馬表ページをスクレイピングしてレース詳細情報を取得します。
  /// (FeaturedRaceモデルに必要な情報を抽出)
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
      // クラス名からグレードを抽出 (例: Icon_GradeType3 -> G3)
      String raceGrade = '';
      if (raceGradeElement != null) {
        final classList = raceGradeElement.classes;
        for (final cls in classList) {
          if (cls.startsWith('Icon_GradeType') && cls.length > 14) { // Icon_GradeTypeXX形式
            raceGrade = 'G${cls.substring(14)}';
            break;
          }
        }
        if (raceGrade.isEmpty && classList.contains('Icon_GradeType13')) { // 特定のアイコンに対する処理
          raceGrade = 'J・G'; // J・Gは障害重賞の可能性
        }
      }
      // もしG1,G2,G3などの情報が直接テキストで取得できるならそちらを優先

      final raceData02 = document.querySelector('div.RaceData02');
      final raceDataText = _safeGetText(raceData02);

      // 例: "2回 新潟 4日目 サラ系３歳以上 オープン (国際)(特指) 別定 21頭"
      final parts = raceDataText.split(' ');
      String venue = '';
      String raceDate = ''; // このページには日付が直接ないので、別途取得するか、FeaturedRaceモデルのraceDateを別の方法で取得する必要がある
      String raceNumber = '';

      // 開催場所とレース番号の抽出 (サンプルHTMLから)
      final raceNumElement = document.querySelector('span.RaceNum');
      raceNumber = _safeGetText(raceNumElement).replaceAll('R', ''); // "7R" -> "7"

      final raceKaisaiWrap = document.querySelector('div.RaceKaisaiWrap ul.Col');
      final activeVenueElement = raceKaisaiWrap?.querySelector('li.Active a');
      venue = _safeGetText(activeVenueElement);

      // 日付は、RaceList_Date_Top の RaceList_DateList から取得可能
      // `<dd class="Active"><a href="../top/race_list.html?kaisai_date=20250803&kaisai_id=2025070304&current_group=1020250802#racelist_top_a" title="8月3日(日)">8月3日<span class="Sun">(日)</span></a></dd>`
      final dateElement = document.querySelector('div.RaceList_Date_Top dd.Active a');
      if (dateElement != null) {
        final dateText = _safeGetText(dateElement);
        // "8月3日(日)" から "8月3日" を抽出
        raceDate = dateText.split('(')[0];
        // 年はトップページから取得するか、別途計算する必要がある（例: 現在の年を使用）
        final currentYear = DateTime.now().year;
        raceDate = '$currentYear年$raceDate'; // 例: "2025年8月3日"
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
          // パスセグメントの3番目がhorseId (例: /horse/2017101423)
          if (uri.pathSegments.length >= 2 && uri.pathSegments[0] == 'horse') {
            horseIds.add(uri.pathSegments[1]);
          }
        }
      }
      return horseIds.toSet().toList(); // 重複を排除してリストに変換
    } catch (e) {
      print('出馬表ページからのホースID抽出中にエラーが発生しました: $e');
      return [];
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
